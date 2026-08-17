import Foundation

struct EdgeVoice: Codable, Hashable, Identifiable, Sendable {
    let shortName: String
    let locale: String
    let gender: String
    let friendlyName: String

    var id: String { shortName }

    var conciseName: String {
        var name = shortName
        let prefix = "\(locale)-"
        if name.hasPrefix(prefix) {
            name.removeFirst(prefix.count)
        }
        if name.hasSuffix("Neural") {
            name.removeLast("Neural".count)
        }
        return name
    }

    var displayName: String {
        "\(conciseName) · \(gender)"
    }
}

struct TextStats: Equatable, Sendable {
    let characters: Int
    let words: Int

    init(_ text: String) {
        characters = text.count
        words = text.split(whereSeparator: \.isWhitespace).count
    }

    var summary: String {
        "\(words.formatted()) \(words == 1 ? "word" : "words") · \(characters.formatted()) \(characters == 1 ? "character" : "characters")"
    }

    func estimatedDuration(rate: Int) -> String {
        guard words > 0 else { return "no audio yet" }
        let seconds = estimatedSeconds(rate: rate)

        if seconds < 55 {
            let rounded = max(5, Int((seconds / 5).rounded()) * 5)
            return "about \(rounded) sec"
        }

        let minutes = max(1, Int((seconds / 60).rounded()))
        if minutes < 60 {
            return "about \(minutes) min"
        }

        let hours = Double(minutes) / 60
        return "about \(hours.formatted(.number.precision(.fractionLength(1)))) hr"
    }

    func estimatedSeconds(rate: Int) -> Double {
        guard words > 0 else { return 0 }
        let wordsPerMinute = 155 * max(0.7, 1 + Double(rate) / 100)
        return Double(words) / wordsPerMinute * 60
    }
}

struct SynthesisProgress: Equatable, Sendable {
    enum Stage: Equatable, Sendable {
        case preparing
        case connecting
        case receiving
        case finalizing
    }

    let stage: Stage
    let fraction: Double
    let receivedAudioSeconds: Double
    let estimatedAudioSeconds: Double
    let estimatedWallSecondsRemaining: Double?

    var percentage: Int {
        min(stage == .finalizing ? 99 : 98, max(0, Int((fraction * 100).rounded())))
    }

    var title: String {
        switch stage {
        case .preparing:
            return "Preparing the voice engine"
        case .connecting:
            return "Connecting to Microsoft"
        case .receiving:
            return "Making your MP3"
        case .finalizing:
            return "Finalizing your MP3"
        }
    }

    var detail: String {
        switch stage {
        case .preparing:
            return "Checking the voice engine…"
        case .connecting:
            return "Connecting to Microsoft…"
        case .finalizing:
            return "Finishing and checking the MP3…"
        case .receiving:
            var pieces = [
                "Receiving audio",
                "\(Self.clock(receivedAudioSeconds)) of about \(Self.clock(estimatedAudioSeconds))"
            ]
            if let estimatedWallSecondsRemaining {
                pieces.append("about \(Self.shortDuration(estimatedWallSecondsRemaining)) left")
            } else {
                pieces.append("calculating time left")
            }
            return pieces.joined(separator: " · ")
        }
    }

    private static func clock(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let minutes = totalSeconds / 60
        let remainder = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", remainder))"
    }

    private static func shortDuration(_ seconds: Double) -> String {
        let rounded = max(1, Int(seconds.rounded()))
        if rounded < 60 {
            return "\(rounded) sec"
        }
        let minutes = Int((Double(rounded) / 60).rounded(.up))
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = Double(minutes) / 60
        return "\(hours.formatted(.number.precision(.fractionLength(1)))) hr"
    }
}

enum EnginePreparationStage: Equatable, Sendable {
    case checking
    case creatingRuntime
    case installingRuntime
    case loadingVoices

    var detail: String {
        switch self {
        case .checking:
            return "Checking the private voice engine…"
        case .creatingRuntime:
            return "Creating the private voice engine. First launch only…"
        case .installingRuntime:
            return "Installing the free voice engine. First launch only…"
        case .loadingVoices:
            return "Loading Microsoft voices…"
        }
    }
}

enum MP3Validator {
    static func isValid(url: URL) -> Bool {
        guard
            let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
            let size = values.fileSize,
            size > 512,
            let handle = try? FileHandle(forReadingFrom: url)
        else {
            return false
        }

        defer { try? handle.close() }
        let header = try? handle.read(upToCount: 3)
        guard let header, header.count >= 2 else { return false }

        if header.count == 3, String(data: header, encoding: .ascii) == "ID3" {
            return true
        }

        return header[0] == 0xFF && (header[1] & 0xE0) == 0xE0
    }
}

enum TTSFailure: LocalizedError {
    case pythonMissing
    case processFailed(String)
    case invalidVoiceResponse
    case emptyAudio
    case helperMissing

    var errorDescription: String? {
        switch self {
        case .pythonMissing:
            return "Python 3 was not found. Install it with Homebrew, then reopen the app."
        case .processFailed(let message):
            return message.isEmpty ? "Microsoft Edge voice service failed." : message
        case .invalidVoiceResponse:
            return "Microsoft returned an unreadable voice list."
        case .emptyAudio:
            return "Microsoft returned no usable MP3 audio."
        case .helperMissing:
            return "The app's Edge voice helper is missing. Rebuild the app."
        }
    }
}
