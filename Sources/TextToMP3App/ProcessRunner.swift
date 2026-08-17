@preconcurrency import Foundation

struct ProcessOutput: Sendable {
    let status: Int32
    let standardOutput: String
    let standardError: String
}

private final class ProcessBox: @unchecked Sendable {
    let process = Process()
    let outputURL: URL
    let errorURL: URL
    let outputHandle: FileHandle
    let errorHandle: FileHandle

    init() throws {
        let directory = FileManager.default.temporaryDirectory
        outputURL = directory.appendingPathComponent("text-to-mp3-\(UUID().uuidString).out")
        errorURL = directory.appendingPathComponent("text-to-mp3-\(UUID().uuidString).err")

        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        outputHandle = try FileHandle(forWritingTo: outputURL)
        errorHandle = try FileHandle(forWritingTo: errorURL)
    }

    func collect(status: Int32) -> ProcessOutput {
        try? outputHandle.close()
        try? errorHandle.close()

        let output = (try? String(contentsOf: outputURL, encoding: .utf8)) ?? ""
        let error = (try? String(contentsOf: errorURL, encoding: .utf8)) ?? ""
        try? FileManager.default.removeItem(at: outputURL)
        try? FileManager.default.removeItem(at: errorURL)

        return ProcessOutput(
            status: status,
            standardOutput: output.trimmingCharacters(in: .whitespacesAndNewlines),
            standardError: error.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func cleanUpAfterLaunchFailure() {
        try? outputHandle.close()
        try? errorHandle.close()
        try? FileManager.default.removeItem(at: outputURL)
        try? FileManager.default.removeItem(at: errorURL)
    }
}

enum ProcessRunner {
    static func run(
        executable: URL,
        arguments: [String],
        currentDirectory: URL? = nil
    ) async throws -> ProcessOutput {
        let box = try ProcessBox()
        box.process.executableURL = executable
        box.process.arguments = arguments
        box.process.currentDirectoryURL = currentDirectory
        box.process.standardOutput = box.outputHandle
        box.process.standardError = box.errorHandle

        let output = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                box.process.terminationHandler = { process in
                    continuation.resume(returning: box.collect(status: process.terminationStatus))
                }

                do {
                    try box.process.run()
                } catch {
                    box.cleanUpAfterLaunchFailure()
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            if box.process.isRunning {
                box.process.terminate()
            }
        }
        try Task.checkCancellation()
        return output
    }
}
