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

extension Notification.Name {
    static let openImageCommand = Notification.Name("openImageCommand")
    static let saveImageCommand = Notification.Name("saveImageCommand")
}

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var cleanedImageData: Data?
    @State private var cleanedTempURL: URL?
    @State private var isCleaning = false
    @State private var errorMessage: String?
    @State private var selectedApproach: String = "bradley-roth"
    
    private var isShowingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
    
    let cleaner = CleaningService()
    let approaches = [
        "bradley-roth", "nick", "sauvola", "niblack", "bataineh"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    ImageContainer(title: "Original Image", data: selectedImageData)
                    VStack {
                        Image(systemName: "arrow.right")
                            .font(.largeTitle)
                        // the cleaning process is so fast, that a progress view is not necessary
                        // if isCleaning { ProgressView().padding() }
                    }
                    ImageContainer(title: "Cleaned Image", data: cleanedImageData)
                }
            }
            .padding()
            .onChange(of: selectedApproach) {
                guard selectedImageData != nil else { return }
                Task { await clean() }
            }
            .onChange(of: selectedImageData) {
                guard selectedImageData != nil else { return }
                Task { await clean() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openImageCommand)) { _ in
                openImageWithPanel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .saveImageCommand)) { _ in
                guard cleanedImageData != nil else { return }
                saveCleanedImage()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                PhotosPicker("Select Image", selection: $selectedItem, matching: .images)
                    .buttonStyle(.bordered)
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
            }
            ToolbarItem(placement: .primaryAction) {
                Picker("", selection: $selectedApproach) {
                    ForEach(approaches, id: \.self) { approach in
                        Text(approach.capitalized).tag(approach)
                    }
                }
                .pickerStyle(.menu)
                .disabled(isCleaning || selectedImageData == nil)
                .help("Choose the algorithm used for image binarization. Although Bradley-Roth is often the best choice, other approaches may yield better results depending on the image characteristics.")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button("Save Image") { saveCleanedImage() }
                    .buttonStyle(.bordered)
                    .disabled(cleanedImageData == nil)
            }
        }
        .alert("Error", isPresented: isShowingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
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
    
    private func openImageWithPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .ppm]
        panel.allowsMultipleSelection = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                selectedImageData = data
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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

