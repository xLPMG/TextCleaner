import SwiftUI
import PhotosUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var cleanedImageData: Data?
    @State private var isCleaning: Bool = false
    @State private var errorMessage: String?
    @State private var debugInfo: String?

    func saveToTempFile(data: Data, ext: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = UUID().uuidString + "." + ext
        let fileURL = tempDir.appendingPathComponent(filename)
        try data.write(to: fileURL)
        return fileURL
    }

    func runImgClean(inputURL: URL, outputURL: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        let inputPath = inputURL.path
        let outputPath = outputURL.path

        // Run the external tool on a background queue so we don't block the UI
        DispatchQueue.global(qos: .userInitiated).async {
            // Resolve the embedded tool path in the app's Executables directory (Contents/MacOS)
            let executablesDir = Bundle.main.executableURL?.deletingLastPathComponent()
            let toolURL = executablesDir?.appendingPathComponent("imgclean")

            guard let toolURL, FileManager.default.fileExists(atPath: toolURL.path) else {
                let pathHint = executablesDir?.path ?? "<unknown>"
                let err = NSError(
                    domain: "ImgClean",
                    code: -1001,
                    userInfo: [NSLocalizedDescriptionKey: "Could not locate 'imgclean' in Executables (Contents/MacOS). Expected at: \(pathHint)/imgclean. Ensure the binary is added to a Copy Files build phase with Destination = Executables and has executable permissions."]
                )
                completion(.failure(err))
                return
            }

            let task = Process()
            task.executableURL = toolURL
            task.arguments = ["-i", inputPath, "-o", outputPath]

            // Capture stderr for better error messages
            let stderrPipe = Pipe()
            task.standardError = stderrPipe

            do {
                try task.run()
                task.waitUntilExit()

                if task.terminationStatus == 0 {
                    do {
                        let outData = try Data(contentsOf: URL(fileURLWithPath: outputPath))
                        completion(.success(outData))
                    } catch {
                        completion(.failure(error))
                    }
                } else {
                    let code = Int(task.terminationStatus)
                    let errData = (try? stderrPipe.fileHandleForReading.readToEnd()) ?? Data()
                    let errStr = String(data: errData, encoding: .utf8) ?? ""
                    let message = errStr.isEmpty ? "imgclean exited with status \(code)" : errStr.trimmingCharacters(in: .whitespacesAndNewlines)
                    let err = NSError(domain: "ImgClean", code: code, userInfo: [NSLocalizedDescriptionKey: message])
                    completion(.failure(err))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 20) {
                    if let data = selectedImageData,
                       let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .padding()
                    } else {
                        Rectangle()
                            .fill(.gray.opacity(0.2))
                            .frame(height: 300)
                            .overlay(Text("No image selected"))
                    }
                    PhotosPicker("Select Image", selection: $selectedItem, matching: .images)
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .onChange(of: selectedItem) {
                    Task {
                        if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                            selectedImageData = data
                            cleanedImageData = nil
                        }
                    }
                }
                VStack(spacing: 20) {
                    if let data = cleanedImageData,
                       let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .padding()
                    } else {
                        Rectangle()
                            .fill(.gray.opacity(0.1))
                            .frame(height: 300)
                            .overlay(Text("No cleaned image"))
                    }
                }
                .padding()
            }
            HStack {
                Button("Clean Text") {
                    guard let data = selectedImageData else { return }
                    isCleaning = true
                    errorMessage = nil
                    debugInfo = nil
                    Task {
                        do {
                            let ext = selectedItem?.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                            let inputURL = try saveToTempFile(data: data, ext: ext)
                            let outputURL = inputURL.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + "." + ext)
                            runImgClean(inputURL: inputURL, outputURL: outputURL) { result in
                                DispatchQueue.main.async {
                                    isCleaning = false
                                    switch result {
                                    case .success(let outData):
                                        cleanedImageData = outData
                                    case .failure(let err):
                                        errorMessage = err.localizedDescription
                                    }
                                }
                            }
                        } catch {
                            isCleaning = false
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .disabled(selectedImageData == nil || isCleaning)
                if isCleaning {
                    ProgressView()
                }
                if let error = errorMessage {
                    ScrollView {
                        Text(error).foregroundColor(.red).font(.system(size: 12)).lineLimit(20)
                    }.frame(maxHeight: 120)
                }
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
