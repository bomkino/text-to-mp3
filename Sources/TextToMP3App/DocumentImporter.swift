import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers

struct ImportedDocument: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case pdf(pages: Int, ocrPages: Int)
        case text
    }

    let filename: String
    let text: String
    let kind: Kind

    var detail: String {
        switch kind {
        case .pdf(let pages, let ocrPages):
            let pageSummary = "\(pages.formatted()) \(pages == 1 ? "page" : "pages")"
            let ocrSummary = ocrPages > 0
                ? " · OCR read \(ocrPages.formatted()) \(ocrPages == 1 ? "scan" : "scans")"
                : ""
            return "\(pageSummary)\(ocrSummary) · \(TextStats(text).summary)"
        case .text:
            return TextStats(text).summary
        }
    }
}

struct DocumentImportProgress: Equatable, Sendable {
    enum Stage: Equatable, Sendable {
        case opening
        case reading
        case ocr

        var title: String {
            switch self {
            case .opening:
                return "Opening your document"
            case .reading:
                return "Reading your document"
            case .ocr:
                return "Reading the scanned pages"
            }
        }
    }

    let stage: Stage
    let fraction: Double
    let detail: String

    var percentage: Int {
        min(100, max(0, Int((fraction * 100).rounded())))
    }
}

enum DocumentImportFailure: LocalizedError {
    case unsupported
    case unreadable
    case passwordProtected
    case noReadableText
    case empty
    case ocrUnavailable
    case ocrFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "Choose a PDF or plain-text file."
        case .unreadable:
            return "That file could not be opened."
        case .passwordProtected:
            return "That PDF is password-protected. Unlock it first, then try again."
        case .noReadableText:
            return "OCR could not find readable English text in that PDF."
        case .empty:
            return "That document does not contain any readable text."
        case .ocrUnavailable:
            return "The app's built-in OCR engine is missing. Reinstall the app, then try again."
        case .ocrFailed:
            return "OCR hit a problem on one scanned page. Your existing script was left alone."
        }
    }
}

enum DocumentImporter {
    static let allowedContentTypes: [UTType] = [.pdf, .plainText]

    static func supports(_ url: URL) -> Bool {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type.conforms(to: .pdf) || type.conforms(to: .plainText)
        }

        switch url.pathExtension.lowercased() {
        case "pdf", "txt", "text", "md", "markdown":
            return true
        default:
            return false
        }
    }

    static func load(
        url: URL,
        progress: @escaping @Sendable (DocumentImportProgress) async -> Void
    ) async throws -> ImportedDocument {
        defer { url.stopAccessingSecurityScopedResource() }

        guard supports(url) else {
            throw DocumentImportFailure.unsupported
        }

        let worker = Task.detached(priority: .userInitiated) {
            if isPDF(url) {
                return try await loadPDF(url: url, progress: progress)
            }
            return try await loadText(url: url, progress: progress)
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private static func isPDF(_ url: URL) -> Bool {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type.conforms(to: .pdf)
        }
        return url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame
    }

    private static func loadPDF(
        url: URL,
        progress: @escaping @Sendable (DocumentImportProgress) async -> Void
    ) async throws -> ImportedDocument {
        await progress(
            DocumentImportProgress(
                stage: .opening,
                fraction: 0,
                detail: "Opening \(url.lastPathComponent)…"
            )
        )

        guard let document = PDFDocument(url: url) else {
            throw DocumentImportFailure.unreadable
        }
        guard !document.isLocked else {
            throw DocumentImportFailure.passwordProtected
        }
        guard document.pageCount > 0 else {
            throw DocumentImportFailure.empty
        }

        let fileManager = FileManager.default
        let jobURL = fileManager.temporaryDirectory
            .appendingPathComponent("TextToMP3-OCR-\(UUID().uuidString)", isDirectory: true)
        var createdJobDirectory = false
        defer {
            if createdJobDirectory {
                try? fileManager.removeItem(at: jobURL)
            }
        }

        var pages: [String] = []
        pages.reserveCapacity(document.pageCount)
        var ocrPageCount = 0
        var averageOCRSeconds: Double?

        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            let pageNumber = index + 1
            let pageFraction = Double(index) / Double(document.pageCount)
            await progress(
                DocumentImportProgress(
                    stage: .reading,
                    fraction: pageFraction,
                    detail: "Checking page \(pageNumber.formatted()) of \(document.pageCount.formatted())…"
                )
            )

            guard let page = document.page(at: index) else { continue }
            let selectableText = page.string?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if !selectableText.isEmpty {
                pages.append(selectableText)
            } else {
                if !createdJobDirectory {
                    try fileManager.createDirectory(at: jobURL, withIntermediateDirectories: true)
                    createdJobDirectory = true
                }

                let eta = averageOCRSeconds.map {
                    " · about \(shortDuration($0 * Double(document.pageCount - index))) left"
                } ?? " · calculating time left"
                await progress(
                    DocumentImportProgress(
                        stage: .ocr,
                        fraction: min(0.98, (Double(index) + 0.2) / Double(document.pageCount)),
                        detail: "OCR page \(pageNumber.formatted()) of \(document.pageCount.formatted())\(eta)"
                    )
                )

                let startedAt = Date()
                let imageURL = jobURL.appendingPathComponent("page-\(pageNumber).png")
                try render(page: page, to: imageURL)
                let recognizedText = try await recognizeText(in: imageURL)
                let elapsed = Date().timeIntervalSince(startedAt)
                averageOCRSeconds = averageOCRSeconds.map { ($0 * 0.7) + (elapsed * 0.3) } ?? elapsed
                ocrPageCount += 1

                if !recognizedText.isEmpty {
                    pages.append(recognizedText)
                }
            }

            await progress(
                DocumentImportProgress(
                    stage: ocrPageCount > 0 ? .ocr : .reading,
                    fraction: Double(pageNumber) / Double(document.pageCount),
                    detail: "Read page \(pageNumber.formatted()) of \(document.pageCount.formatted())."
                )
            )
        }

        let text = pages
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw DocumentImportFailure.noReadableText
        }

        return ImportedDocument(
            filename: url.lastPathComponent,
            text: text,
            kind: .pdf(pages: document.pageCount, ocrPages: ocrPageCount)
        )
    }

    private static func render(page: PDFPage, to destinationURL: URL) throws {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else {
            throw DocumentImportFailure.unreadable
        }

        let scale = min(3.0, 2_400 / max(bounds.width, bounds.height))
        let size = CGSize(
            width: max(1, (bounds.width * scale).rounded()),
            height: max(1, (bounds.height * scale).rounded())
        )
        let image = page.thumbnail(of: size, for: .mediaBox)
        guard
            let data = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: data),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            throw DocumentImportFailure.unreadable
        }
        try png.write(to: destinationURL, options: .atomic)
    }

    private static func recognizeText(in imageURL: URL) async throws -> String {
        let executable = try tesseractExecutableURL()
        let tessdata = try tessdataURL()
        let result = try await ProcessRunner.run(
            executable: executable,
            arguments: [
                imageURL.path,
                "stdout",
                "--tessdata-dir", tessdata.path,
                "-l", "eng"
            ]
        )
        guard result.status == 0 else {
            let message = result.standardError
                .split(separator: "\n")
                .suffix(4)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw DocumentImportFailure.ocrFailed(message)
        }

        return result.standardOutput
            .replacingOccurrences(of: "\u{000C}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func tesseractExecutableURL() throws -> URL {
        if let resourceURL = Bundle.main.resourceURL {
            let bundled = resourceURL.appendingPathComponent("OCR/bin/tesseract")
            if FileManager.default.isExecutableFile(atPath: bundled.path) {
                return bundled
            }
        }

        #if DEBUG
        for path in ["/opt/homebrew/bin/tesseract", "/usr/local/bin/tesseract"]
        where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        #endif

        throw DocumentImportFailure.ocrUnavailable
    }

    private static func tessdataURL() throws -> URL {
        if let resourceURL = Bundle.main.resourceURL {
            let bundled = resourceURL.appendingPathComponent("OCR/tessdata", isDirectory: true)
            if FileManager.default.fileExists(atPath: bundled.appendingPathComponent("eng.traineddata").path) {
                return bundled
            }
        }

        #if DEBUG
        for path in [
            "/opt/homebrew/share/tessdata",
            "/opt/homebrew/opt/tesseract/share/tessdata",
            "/usr/local/share/tessdata",
            "/usr/local/opt/tesseract/share/tessdata"
        ] where FileManager.default.fileExists(atPath: "\(path)/eng.traineddata") {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        #endif

        throw DocumentImportFailure.ocrUnavailable
    }

    private static func shortDuration(_ seconds: Double) -> String {
        let rounded = max(1, Int(seconds.rounded(.up)))
        if rounded < 60 { return "\(rounded) sec" }
        let minutes = Int((Double(rounded) / 60).rounded(.up))
        return "\(minutes) min"
    }

    private static func loadText(
        url: URL,
        progress: @escaping @Sendable (DocumentImportProgress) async -> Void
    ) async throws -> ImportedDocument {
        await progress(
            DocumentImportProgress(
                stage: .reading,
                fraction: 0.15,
                detail: "Reading \(url.lastPathComponent)…"
            )
        )

        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw DocumentImportFailure.unreadable
        }

        let encodings: [String.Encoding] = [
            .utf8,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            .windowsCP1252,
            .isoLatin1
        ]
        guard let decoded = encodings.lazy.compactMap({ String(data: data, encoding: $0) }).first else {
            throw DocumentImportFailure.unreadable
        }

        let text = decoded
            .replacingOccurrences(of: "\u{0000}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw DocumentImportFailure.empty
        }

        await progress(
            DocumentImportProgress(
                stage: .reading,
                fraction: 1,
                detail: "Text ready."
            )
        )
        return ImportedDocument(filename: url.lastPathComponent, text: text, kind: .text)
    }
}
