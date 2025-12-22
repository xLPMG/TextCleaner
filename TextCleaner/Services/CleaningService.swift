//
//  CleaningService.swift
//  TextCleaner
//
//  Created by Luca-Philipp Grumbach on 22.12.25.
//
import Foundation

struct CleanResult {
    let cleanedData: Data
    let tempURL: URL
}

final class CleaningService {

    /**
     Cleans the supplied image using imgclean
     @param data the raw image data to be cleaned
     @param ext file extension of the image
     */
    func cleanImage(data: Data, ext: String) async throws -> CleanResult {
        // save image data to temporary file
        let input = try saveTempFile(data: data, ext: ext)
        let output = input.deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)

        let cleanedData = try await runImgClean(input: input, output: output)
        // delete input data again after cleaning
        try? FileManager.default.removeItem(at: input)

        return CleanResult(cleanedData: cleanedData, tempURL: output)
    }

    private func saveTempFile(data: Data, ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try data.write(to: url)
        return url
    }

    private func imgcleanExecutable() throws -> URL {
        guard let dir = Bundle.main.executableURL?.deletingLastPathComponent() else {
            throw simpleError("Cannot locate Executables directory")
        }
        let exe = dir.appendingPathComponent("imgclean")
        guard FileManager.default.fileExists(atPath: exe.path) else {
            throw simpleError("'imgclean' missing. Check Copy Files > Executables.")
        }
        return exe
    }

    private func simpleError(_ msg: String) -> NSError {
        NSError(domain: "ImgClean", code: -1,
                userInfo: [NSLocalizedDescriptionKey: msg])
    }

    private func runImgClean(input: URL, output: URL) async throws -> Data {
        let tool = try imgcleanExecutable()

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let task = Process()
                task.executableURL = tool
                task.arguments = ["-i", input.path, "-o", output.path]

                let stderr = Pipe()
                task.standardError = stderr

                do {
                    try task.run()
                    task.waitUntilExit()

                    guard task.terminationStatus == 0 else {
                        let message = String(
                            data: stderr.fileHandleForReading.readDataToEndOfFile(),
                            encoding: .utf8
                        ) ?? "imgclean exited \(task.terminationStatus)"
                        continuation.resume(throwing: self.simpleError(message))
                        return
                    }

                    let data = try Data(contentsOf: output)
                    continuation.resume(returning: data)

                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
