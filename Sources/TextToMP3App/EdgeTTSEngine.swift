import Foundation

actor EdgeTTSEngine {
    private let edgeTTSVersion = "7.2.8"
    private let fileManager = FileManager.default

    private var applicationSupportURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Text to MP3", isDirectory: true)
    }

    private var runtimeURL: URL {
        applicationSupportURL.appendingPathComponent("EdgeRuntime", isDirectory: true)
    }

    private var runtimePythonURL: URL {
        runtimeURL.appendingPathComponent("bin/python3")
    }

    private var versionMarkerURL: URL {
        runtimeURL.appendingPathComponent("edge-tts-version")
    }

    func prepare(
        progress: (@Sendable (EnginePreparationStage) async -> Void)? = nil
    ) async throws {
        await progress?(.checking)
        try fileManager.createDirectory(
            at: applicationSupportURL,
            withIntermediateDirectories: true
        )

        let installedVersion = try? String(contentsOf: versionMarkerURL, encoding: .utf8)
        if
            fileManager.isExecutableFile(atPath: runtimePythonURL.path),
            installedVersion?.trimmingCharacters(in: .whitespacesAndNewlines) == edgeTTSVersion
        {
            return
        }

        if !fileManager.isExecutableFile(atPath: runtimePythonURL.path) {
            await progress?(.creatingRuntime)
            let python = try systemPythonURL()
            let result = try await ProcessRunner.run(
                executable: python,
                arguments: ["-m", "venv", runtimeURL.path]
            )
            try requireSuccess(result, fallback: "Could not create free voice engine.")
        }

        await progress?(.installingRuntime)
        let install = try await ProcessRunner.run(
            executable: runtimePythonURL,
            arguments: [
                "-m", "pip", "install",
                "--disable-pip-version-check",
                "--no-input",
                "edge-tts==\(edgeTTSVersion)"
            ]
        )
        try requireSuccess(install, fallback: "Could not install free Edge voice engine.")
        try edgeTTSVersion.write(to: versionMarkerURL, atomically: true, encoding: .utf8)
    }

    func voices(
        progress: @escaping @Sendable (EnginePreparationStage) async -> Void
    ) async throws -> [EdgeVoice] {
        try await prepare(progress: progress)
        await progress(.loadingVoices)
        let helper = try helperURL()
        let result = try await ProcessRunner.run(
            executable: runtimePythonURL,
            arguments: [helper.path, "voices"]
        )
        try requireSuccess(result, fallback: "Could not load Microsoft voices.")

        guard
            let data = result.standardOutput.data(using: .utf8),
            let voices = try? JSONDecoder().decode([EdgeVoice].self, from: data),
            !voices.isEmpty
        else {
            throw TTSFailure.invalidVoiceResponse
        }

        return voices.sorted {
            if $0.locale == $1.locale {
                return $0.shortName.localizedStandardCompare($1.shortName) == .orderedAscending
            }
            return $0.locale.localizedStandardCompare($1.locale) == .orderedAscending
        }
    }

    func synthesize(
        text: String,
        voice: String,
        rate: Int,
        destinationURL: URL,
        progress: @escaping @Sendable (SynthesisProgress) async -> Void
    ) async throws {
        let estimatedAudioSeconds = TextStats(text).estimatedSeconds(rate: rate)
        await progress(
            SynthesisProgress(
                stage: .preparing,
                fraction: 0,
                receivedAudioSeconds: 0,
                estimatedAudioSeconds: estimatedAudioSeconds,
                estimatedWallSecondsRemaining: nil
            )
        )

        try await prepare()
        let helper = try helperURL()
        let jobURL = applicationSupportURL
            .appendingPathComponent("Jobs", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: jobURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: jobURL) }

        let textURL = jobURL.appendingPathComponent("input.txt")
        try text.write(to: textURL, atomically: true, encoding: .utf8)

        let temporaryOutputURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destinationURL.lastPathComponent).\(UUID().uuidString).tmp")
        defer { try? fileManager.removeItem(at: temporaryOutputURL) }

        await progress(
            SynthesisProgress(
                stage: .connecting,
                fraction: 0,
                receivedAudioSeconds: 0,
                estimatedAudioSeconds: estimatedAudioSeconds,
                estimatedWallSecondsRemaining: nil
            )
        )

        let progressTask = Task {
            var previousSize: Int64 = -1
            var samples: [(date: Date, bytes: Double)] = []
            var smoothedRemaining: Double?
            var highestFraction = 0.0

            while !Task.isCancelled {
                let attributes = try? fileManager.attributesOfItem(
                    atPath: temporaryOutputURL.path
                )
                let byteCount = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
                let now = Date()

                samples.append((now, Double(byteCount)))
                samples.removeAll { now.timeIntervalSince($0.date) > 12 }

                if byteCount != previousSize {
                    previousSize = byteCount
                    let receivedSeconds = Double(byteCount * 8) / 48_000
                    let adaptiveEstimatedSeconds = max(
                        estimatedAudioSeconds,
                        receivedSeconds / 0.98
                    )
                    let rawFraction = adaptiveEstimatedSeconds > 0
                        ? receivedSeconds / adaptiveEstimatedSeconds
                        : 0
                    let displayFraction = max(
                        highestFraction,
                        min(0.98, max(0, rawFraction))
                    )
                    highestFraction = displayFraction

                    var remaining: Double?
                    if let first = samples.first,
                       let last = samples.last,
                       last.date.timeIntervalSince(first.date) >= 2,
                       last.bytes > first.bytes {
                        let bytesPerSecond = (last.bytes - first.bytes)
                            / last.date.timeIntervalSince(first.date)
                        let estimatedTotalBytes = adaptiveEstimatedSeconds * 6_000
                        let rawRemaining = max(0, estimatedTotalBytes - Double(byteCount))
                            / bytesPerSecond
                        if rawRemaining.isFinite {
                            let clamped = min(86_400, rawRemaining)
                            smoothedRemaining = smoothedRemaining.map {
                                ($0 * 0.72) + (clamped * 0.28)
                            } ?? clamped
                            remaining = smoothedRemaining
                        }
                    }

                    await progress(
                        SynthesisProgress(
                            stage: receivedSeconds > 0 ? .receiving : .connecting,
                            fraction: displayFraction,
                            receivedAudioSeconds: receivedSeconds,
                            estimatedAudioSeconds: adaptiveEstimatedSeconds,
                            estimatedWallSecondsRemaining: remaining
                        )
                    )
                }

                try? await Task.sleep(for: .milliseconds(500))
            }
        }
        defer { progressTask.cancel() }

        let rateArgument = rate >= 0 ? "+\(rate)%" : "\(rate)%"
        let result = try await ProcessRunner.run(
            executable: runtimePythonURL,
            arguments: [
                helper.path,
                "synthesize",
                "--text-file", textURL.path,
                "--output", temporaryOutputURL.path,
                "--voice", voice,
                "--rate", rateArgument
            ]
        )
        try requireSuccess(result, fallback: "Microsoft Edge voice service failed.")

        let finalByteCount = ((try? fileManager.attributesOfItem(
            atPath: temporaryOutputURL.path
        )[.size]) as? NSNumber)?.int64Value ?? 0
        let finalAudioSeconds = Double(finalByteCount * 8) / 48_000
        await progress(
            SynthesisProgress(
                stage: .finalizing,
                fraction: 0.99,
                receivedAudioSeconds: finalAudioSeconds,
                estimatedAudioSeconds: max(estimatedAudioSeconds, finalAudioSeconds),
                estimatedWallSecondsRemaining: 0
            )
        )

        guard MP3Validator.isValid(url: temporaryOutputURL) else {
            throw TTSFailure.emptyAudio
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            _ = try fileManager.replaceItemAt(destinationURL, withItemAt: temporaryOutputURL)
        } else {
            try fileManager.moveItem(at: temporaryOutputURL, to: destinationURL)
        }
    }

    private func helperURL() throws -> URL {
        if let url = Bundle.main.url(forResource: "edge_helper", withExtension: "py") {
            return url
        }

        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "edge_helper", withExtension: "py") {
            return url
        }
        #endif
        throw TTSFailure.helperMissing
    }

    private func systemPythonURL() throws -> URL {
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]

        for path in candidates where fileManager.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        throw TTSFailure.pythonMissing
    }

    private func requireSuccess(_ result: ProcessOutput, fallback: String) throws {
        guard result.status == 0 else {
            let usefulMessage = result.standardError
                .split(separator: "\n")
                .suffix(6)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw TTSFailure.processFailed(usefulMessage.isEmpty ? fallback : usefulMessage)
        }
    }
}
