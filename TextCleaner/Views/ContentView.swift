//
//  ContentView.swift
//  TextCleaner
//
//  Created by Luca-Philipp Grumbach on 21.12.25.
//
import SwiftUI
import PhotosUI

extension UTType {
    static let ppm = UTType(filenameExtension: "ppm")!
}

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var cleanedImageData: Data?
    @State private var cleanedTempURL: URL?
    @State private var isCleaning = false
    @State private var errorMessage: String?
    @State private var selectedApproach: String = "bradley-roth"
    
    let cleaner = CleaningService()
    let approaches = [
        "bradley-roth", "nick", "sauvola", "niblack", "bataineh"
    ]

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                VStack(spacing: 20) {
                    ImageContainer(title: "Original Image", data: selectedImageData)
                    
                    PhotosPicker("Select Image", selection: $selectedItem, matching: .images)
                        .buttonStyle(.borderedProminent)
                        .onChange(of: selectedItem) {
                            Task {
                                if let data = try? await selectedItem?.loadTransferable(type: Data.self),
                                   let ext = selectedItem?.supportedContentTypes.first?.preferredFilenameExtension?.lowercased(),
                                   ["jpg","jpeg","png","ppm"].contains(ext)
                                {
                                    selectedImageData = data
                                } else {
                                    errorMessage = "Unsupported file type"
                                }
                            }
                        }
                }.padding()
                
                VStack(spacing: 20) {
                    ImageContainer(title: "Cleaned Image", data: cleanedImageData)
                    
                    Button("Save Image") { saveCleanedImage() }
                        .buttonStyle(.borderedProminent)
                        .disabled(cleanedImageData == nil)
                }.padding()
            }

            if selectedImageData == nil {
                Text("Please select an image to clean.")
            } else {
                HStack {
                    Picker("", selection: $selectedApproach) {
                        ForEach(approaches, id: \.self) { approach in
                            Text(approach.capitalized).tag(approach)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(isCleaning || selectedImageData == nil)
                    .help("Choose the algorithm used for image binarization. Although Bradley-Roth is often the best choice, other approaches may yield better results depending on the image characteristics.")

                    Button("Clean Text") { Task { await clean() } }
                        .disabled(isCleaning || selectedImageData == nil)
                }.padding()
            }

            if isCleaning { ProgressView().padding() }
            if let errorMessage { Text(errorMessage).foregroundColor(.red) }
        }
        .padding()
    }

    private func clean() async {
        guard let data = selectedImageData else { return }
        isCleaning = true
        errorMessage = nil

        do {
            let ext = selectedItem?.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
            let result = try await cleaner.cleanImage(data: data, ext: ext, approach: selectedApproach)
            cleanedImageData = result.cleanedData
            cleanedTempURL = result.tempURL
        } catch {
            errorMessage = error.localizedDescription
        }

        isCleaning = false
    }

    private func saveCleanedImage() {
        guard let data = cleanedImageData,
              let tmp = cleanedTempURL else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.jpeg, .png, .ppm]
        panel.nameFieldStringValue = "cleaned-image"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
                try? FileManager.default.removeItem(at: tmp)
                cleanedTempURL = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview { ContentView() }
