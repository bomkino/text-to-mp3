import AppKit
import PDFKit
import Testing
@testable import TextToMP3App

struct DocumentImporterTests {
    @Test
    func plainTextImportPreservesParagraphs() async throws {
        let fixture = try #require(
            Bundle.module.url(
                forResource: "sample",
                withExtension: "txt",
                subdirectory: "Fixtures"
            )
        )

        let imported = try await DocumentImporter.load(url: fixture) { _ in }

        #expect(TextStats(imported.text).words == 26)
        #expect(imported.text.contains("\n\n"))
        #expect(imported.kind == .text)
    }

    @Test
    func imageOnlyPDFUsesOCR() async throws {
        let pdfURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextToMP3-Scanned-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: pdfURL) }
        try makeScannedPDF(at: pdfURL)

        let recorder = ProgressRecorder()
        let imported = try await DocumentImporter.load(url: pdfURL) { progress in
            await recorder.record(progress.stage)
        }
        let stages = await recorder.stages

        #expect(stages.contains(.ocr))
        #expect(imported.text.contains("Text to MP3 OCR test"))
        #expect(imported.text.contains("private on-device OCR"))
        #expect(imported.kind == .pdf(pages: 1, ocrPages: 1))
    }

    @Test
    func cancellingOCRStopsTheImport() async throws {
        let pdfURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextToMP3-Cancel-OCR-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: pdfURL) }
        try makeScannedPDF(at: pdfURL, pageCount: 8)

        let importTask = Task {
            try await DocumentImporter.load(url: pdfURL) { _ in }
        }
        try await Task.sleep(for: .milliseconds(100))
        importTask.cancel()

        var didCancel = false
        do {
            _ = try await importTask.value
        } catch is CancellationError {
            didCancel = true
        }
        #expect(didCancel)
    }

    private func makeScannedPDF(at destination: URL, pageCount: Int = 1) throws {
        let pageSize = CGSize(width: 612, height: 792)
        let image = NSImage(size: pageSize)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: pageSize).fill()

        let style = NSMutableParagraphStyle()
        style.lineSpacing = 8
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .regular),
            .foregroundColor: NSColor.black,
            .paragraphStyle: style
        ]
        NSString(string: "Text to MP3 OCR test\nThis page proves private on-device OCR works.")
            .draw(in: NSRect(x: 48, y: 620, width: 516, height: 120), withAttributes: attributes)
        image.unlockFocus()

        let document = PDFDocument()
        for index in 0..<pageCount {
            guard let page = PDFPage(image: image) else { throw TestSetupFailure.pdfPage }
            document.insert(page, at: index)
        }
        guard document.write(to: destination) else { throw TestSetupFailure.pdfWrite }
    }
}

private actor ProgressRecorder {
    private(set) var stages: [DocumentImportProgress.Stage] = []

    func record(_ stage: DocumentImportProgress.Stage) {
        stages.append(stage)
    }
}

private enum TestSetupFailure: Error {
    case pdfPage
    case pdfWrite
}
