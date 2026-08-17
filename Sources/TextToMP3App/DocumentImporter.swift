import Foundation
import PDFKit
import UniformTypeIdentifiers

struct ImportedDocument: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case pdf(pages: Int)
        case text
    }

    let filename: String
    let text: String
    let kind: Kind

    var detail: String {
        switch kind {
        case .pdf(let pages):
            return "\(pages.formatted()) \(pages == 1 ? "page" : "pages") · \(TextStats(text).summary)"
        case .text:
            return TextStats(text).summary
        }
    }
}

struct DocumentImportProgress: Equatable, Sendable {
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

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "Choose a PDF or plain-text file."
        case .unreadable:
            return "That file could not be opened."
        case .passwordProtected:
            return "That PDF is password-protected. Unlock it first, then try again."
        case .noReadableText:
            return "That PDF has no selectable text. Run OCR on the scan first, then try again."
        case .empty:
            return "That document does not contain any readable text."
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

        return try await Task.detached(priority: .userInitiated) {
            if isPDF(url) {
                return try await loadPDF(url: url, progress: progress)
            }
            return try await loadText(url: url, progress: progress)
        }.value
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
        await progress(DocumentImportProgress(fraction: 0, detail: "Opening \(url.lastPathComponent)…"))

        guard let document = PDFDocument(url: url) else {
            throw DocumentImportFailure.unreadable
        }
        guard !document.isLocked else {
            throw DocumentImportFailure.passwordProtected
        }
        guard document.pageCount > 0 else {
            throw DocumentImportFailure.empty
        }

        var pages: [String] = []
        pages.reserveCapacity(document.pageCount)

        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            if let pageText = document.page(at: index)?.string,
               !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pages.append(pageText)
            }

            let completed = index + 1
            await progress(
                DocumentImportProgress(
                    fraction: Double(completed) / Double(document.pageCount),
                    detail: "Reading page \(completed.formatted()) of \(document.pageCount.formatted())…"
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
            kind: .pdf(pages: document.pageCount)
        )
    }

    private static func loadText(
        url: URL,
        progress: @escaping @Sendable (DocumentImportProgress) async -> Void
    ) async throws -> ImportedDocument {
        await progress(DocumentImportProgress(fraction: 0.15, detail: "Reading \(url.lastPathComponent)…"))

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

        await progress(DocumentImportProgress(fraction: 1, detail: "Text ready."))
        return ImportedDocument(filename: url.lastPathComponent, text: text, kind: .text)
    }
}
