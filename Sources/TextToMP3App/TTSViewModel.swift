import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class TTSViewModel: ObservableObject {
    private static let defaultLocale = "en-US"
    private static let defaultVoiceID = "en-US-AvaMultilingualNeural"
    private static let defaultRate = 50
    private static let preferenceVersion = 3

    private static let preferredUSFemaleVoiceIDs = [
        "en-US-AvaMultilingualNeural",
        "en-US-AvaNeural",
        "en-US-EmmaMultilingualNeural",
        "en-US-EmmaNeural",
        "en-US-JennyNeural",
        "en-US-AriaNeural"
    ]

    enum State: Equatable {
        case idle
        case preparing
        case ready
        case generating
        case complete(URL)
        case failed(String)
    }

    enum DocumentState: Equatable {
        case idle
        case importing(String)
        case imported(filename: String, detail: String)
        case failed(String)
    }

    @Published var text = "" {
        didSet {
            guard text != oldValue else { return }
            if case .imported = documentState {
                documentState = .idle
                documentProgress = nil
            } else if case .failed = documentState {
                documentState = .idle
            }
            if case .complete = state {
                state = .ready
            } else if case .failed = state, !voices.isEmpty {
                state = .ready
            }
        }
    }
    @Published private(set) var voices: [EdgeVoice] = []
    @Published private(set) var state: State = .idle
    @Published private(set) var selectedLocale = TTSViewModel.defaultLocale
    @Published private(set) var selectedVoiceID = TTSViewModel.defaultVoiceID
    @Published private(set) var rate = TTSViewModel.defaultRate
    @Published private(set) var lastOutputURL: URL?
    @Published private(set) var generationProgress: SynthesisProgress?
    @Published private(set) var documentState: DocumentState = .idle
    @Published private(set) var documentProgress: DocumentImportProgress?
    @Published private(set) var setupStage: EnginePreparationStage = .checking

    private let engine = EdgeTTSEngine()
    private var generationTask: Task<Void, Never>?
    private var documentTask: Task<Void, Never>?
    private var didStart = false

    var stats: TextStats { TextStats(text) }

    var isPreparing: Bool { state == .preparing }

    var isGenerating: Bool { state == .generating }

    var isImporting: Bool {
        if case .importing = documentState { return true }
        return false
    }

    var isBusy: Bool { isPreparing || isGenerating || isImporting }

    var hasError: Bool {
        if case .failed = documentState { return true }
        if case .failed = state { return true }
        return false
    }

    var needsSetupRetry: Bool { hasError && voices.isEmpty }

    var canRevealLastOutput: Bool { lastOutputURL != nil }

    var canImportDocument: Bool { !isGenerating && !isImporting }

    var activeProgressFraction: Double? {
        if isGenerating { return generationProgress?.fraction }
        if isImporting { return documentProgress?.fraction }
        return nil
    }

    var activeProgressPercentage: Int? {
        if isGenerating { return generationProgress?.percentage }
        if isImporting { return documentProgress?.percentage }
        return nil
    }

    var locales: [String] {
        Array(Set(voices.map(\.locale))).sorted {
            localeName($0).localizedStandardCompare(localeName($1)) == .orderedAscending
        }
    }

    var voicesForSelectedLocale: [EdgeVoice] {
        voices.filter { $0.locale == selectedLocale }
    }

    var canGenerate: Bool {
        let available: Bool
        switch state {
        case .ready, .complete:
            available = true
        case .failed:
            available = !voices.isEmpty
        default:
            available = false
        }
        return available && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var primaryActionTitle: String {
        switch state {
        case .complete:
            return "Generate again"
        case .failed where !voices.isEmpty:
            return "Try again"
        default:
            return "Generate MP3"
        }
    }

    var rateDescription: String {
        let multiplier = max(0.7, 1 + Double(rate) / 100)
        let formatted = multiplier.formatted(
            .number.precision(.fractionLength(0...2))
        )
        return rate == 0 ? "1× natural" : "\(formatted)×"
    }

    var statusTitle: String {
        if isGenerating { return generationProgress?.title ?? "Preparing your MP3" }
        if case .failed(let message) = state, voices.isEmpty, !message.isEmpty {
            return "Couldn’t load the voices"
        }

        switch documentState {
        case .importing:
            return "Reading your document"
        case .imported:
            return "Document ready"
        case .failed:
            return "Couldn’t read that file"
        case .idle:
            break
        }

        switch state {
        case .idle:
            return "Starting"
        case .preparing:
            return "Warming up the voices"
        case .ready:
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Ready when you are"
                : "Ready to make your MP3"
        case .generating:
            return generationProgress?.title ?? "Preparing your MP3"
        case .complete:
            return "MP3 saved"
        case .failed:
            return voices.isEmpty ? "Couldn’t load the voices" : "That didn’t work"
        }
    }

    var statusDetail: String {
        if isGenerating {
            return generationProgress?.detail ?? "Checking the voice engine…"
        }
        if case .failed(let message) = state, voices.isEmpty {
            return message
        }

        switch documentState {
        case .importing:
            return documentProgress?.detail ?? "Opening the file…"
        case .imported(let filename, let detail):
            return "\(filename) · \(detail)"
        case .failed(let message):
            return message
        case .idle:
            break
        }

        switch state {
        case .idle:
            return "One moment…"
        case .preparing:
            return setupStage.detail
        case .ready:
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Paste or type something above."
                : "\(stats.estimatedDuration(rate: rate)) · \(rateDescription.lowercased())"
        case .generating:
            return generationProgress?.detail ?? "Checking the voice engine…"
        case .complete(let url):
            return url.lastPathComponent
        case .failed(let message):
            return message
        }
    }

    var statusSymbol: String {
        if isImporting { return "doc.text.magnifyingglass" }
        if case .imported = documentState { return "doc.text" }
        if case .failed = documentState { return "exclamationmark" }

        switch state {
        case .complete:
            return "checkmark"
        case .failed:
            return "exclamationmark"
        case .idle, .preparing:
            return "ellipsis"
        case .ready:
            return "waveform"
        case .generating:
            return "arrow.triangle.2.circlepath"
        }
    }

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        Task { await loadVoices() }
    }

    func retrySetup() {
        Task { await loadVoices() }
    }

    func selectLocale(_ locale: String) {
        selectedLocale = locale
        if let preferred = voices.first(where: { $0.locale == locale && $0.shortName == selectedVoiceID }) {
            selectedVoiceID = preferred.shortName
        } else {
            let localeVoices = voices.filter { $0.locale == locale }
            selectedVoiceID = preferredVoice(in: localeVoices)?.shortName
                ?? selectedVoiceID
        }
        savePreferences()
    }

    func selectVoice(_ voiceID: String) {
        selectedVoiceID = voiceID
        savePreferences()
    }

    func setRate(_ value: Double) {
        rate = Int(value.rounded())
        savePreferences()
    }

    func openDocumentPicker() {
        guard canImportDocument else { return }

        let panel = NSOpenPanel()
        panel.title = "Open a Document"
        panel.prompt = "Open"
        panel.message = "Choose a PDF or plain-text file. The document stays on this Mac."
        panel.allowedContentTypes = DocumentImporter.allowedContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        _ = importDocument(at: url)
    }

    @discardableResult
    func importDocument(at url: URL) -> Bool {
        guard canImportDocument, DocumentImporter.supports(url) else {
            if canImportDocument {
                documentState = .failed(DocumentImportFailure.unsupported.localizedDescription)
                announce("Could not read that file. Choose a PDF or plain-text file.", priority: .high)
            }
            return false
        }

        documentTask = Task { [self] in
            documentState = .importing(url.lastPathComponent)
            documentProgress = nil

            do {
                let document = try await DocumentImporter.load(
                    url: url,
                    progress: { progress in
                        await self.updateDocumentProgress(progress)
                    }
                )
                try Task.checkCancellation()
                text = document.text
                documentProgress = nil
                documentState = .imported(filename: document.filename, detail: document.detail)
                announce("\(document.filename) ready. \(document.detail)")
            } catch is CancellationError {
                documentProgress = nil
                documentState = .idle
            } catch {
                documentProgress = nil
                documentState = .failed(error.localizedDescription)
                announce("Could not read that file. \(error.localizedDescription)", priority: .high)
            }
            documentTask = nil
        }
        return true
    }

    func generate() {
        guard canGenerate else { return }
        let script = text
        let voice = selectedVoiceID
        let speakingRate = rate
        guard let destination = chooseDestination(for: script) else { return }

        generationTask = Task { [self] in
            state = .generating
            generationProgress = nil

            do {
                try await engine.synthesize(
                    text: script,
                    voice: voice,
                    rate: speakingRate,
                    destinationURL: destination,
                    progress: { progress in
                        await self.updateGenerationProgress(progress)
                    }
                )
                lastOutputURL = destination
                generationProgress = nil
                state = .complete(destination)
                announce("MP3 saved as \(destination.lastPathComponent)")
            } catch is CancellationError {
                generationProgress = nil
                state = .ready
                announce("MP3 generation cancelled")
            } catch {
                generationProgress = nil
                state = .failed(error.localizedDescription)
                announce("MP3 generation failed. \(error.localizedDescription)", priority: .high)
            }
            generationTask = nil
        }
    }

    func cancel() {
        generationTask?.cancel()
    }

    func revealLastOutput() {
        guard let url = lastOutputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func clear() {
        text = ""
        documentState = .idle
        documentProgress = nil
        if case .complete = state {
            state = .ready
        }
    }

    func localeName(_ identifier: String) -> String {
        Locale.current.localizedString(
            forIdentifier: identifier.replacingOccurrences(of: "-", with: "_")
        ) ?? identifier
    }

    private func loadVoices() async {
        state = .preparing
        do {
            voices = try await engine.voices { stage in
                await self.updateSetupStage(stage)
            }
            restorePreferences()
            state = .ready
            announce("\(voices.count) voices ready")
        } catch {
            state = .failed(error.localizedDescription)
            announce("Could not load voices. \(error.localizedDescription)", priority: .high)
        }
    }

    private func restorePreferences() {
        let defaults = UserDefaults.standard
        let needsDefaultUpgrade = defaults.integer(forKey: "preferenceVersion") < Self.preferenceVersion
        let savedLocale = needsDefaultUpgrade
            ? Self.defaultLocale
            : (defaults.string(forKey: "selectedLocale") ?? Self.defaultLocale)
        let savedVoice = needsDefaultUpgrade
            ? Self.defaultVoiceID
            : (defaults.string(forKey: "selectedVoice") ?? Self.defaultVoiceID)
        let savedRate = needsDefaultUpgrade
            ? Self.defaultRate
            : (defaults.object(forKey: "rate") as? Int ?? Self.defaultRate)

        selectedLocale = locales.contains(savedLocale) ? savedLocale : (locales.first ?? Self.defaultLocale)
        let localeVoices = voices.filter { $0.locale == selectedLocale }
        selectedVoiceID = localeVoices.contains(where: { $0.shortName == savedVoice })
            ? savedVoice
            : (preferredVoice(in: localeVoices)?.shortName ?? voices.first?.shortName ?? savedVoice)
        rate = min(100, max(-30, savedRate))
        savePreferences()
    }

    private func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(selectedLocale, forKey: "selectedLocale")
        defaults.set(selectedVoiceID, forKey: "selectedVoice")
        defaults.set(rate, forKey: "rate")
        defaults.set(Self.preferenceVersion, forKey: "preferenceVersion")
    }

    private func updateGenerationProgress(_ progress: SynthesisProgress) {
        guard isGenerating else { return }
        generationProgress = progress
    }

    private func updateDocumentProgress(_ progress: DocumentImportProgress) {
        guard isImporting else { return }
        documentProgress = progress
    }

    private func updateSetupStage(_ stage: EnginePreparationStage) {
        guard isPreparing else { return }
        setupStage = stage
    }

    private func preferredVoice(in localeVoices: [EdgeVoice]) -> EdgeVoice? {
        if selectedLocale == Self.defaultLocale {
            for voiceID in Self.preferredUSFemaleVoiceIDs {
                if let voice = localeVoices.first(where: { $0.shortName == voiceID }) {
                    return voice
                }
            }
        }

        return localeVoices.first(where: { $0.gender.caseInsensitiveCompare("Female") == .orderedSame })
            ?? localeVoices.first
    }

    private func chooseDestination(for text: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Save MP3"
        panel.prompt = "Generate"
        panel.message = "Choose where your MP3 should live."
        panel.nameFieldStringValue = suggestedFilename(for: text)
        panel.allowedContentTypes = [.mp3]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func suggestedFilename(for text: String) -> String {
        let firstLine = text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? ""
        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-_"))
        let cleaned = firstLine.unicodeScalars
            .map { allowed.contains($0) ? Character(String($0)) : " " }
        let words = String(cleaned)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let stem = String(words.prefix(48)).trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(stem.isEmpty ? "Speech" : stem).mp3"
    }

    private func announce(
        _ message: String,
        priority: NSAccessibilityPriorityLevel = .medium
    ) {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: priority.rawValue
            ]
        )
    }
}
