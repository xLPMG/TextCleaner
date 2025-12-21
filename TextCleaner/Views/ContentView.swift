import SwiftUI
import PhotosUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?

    var body: some View {
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
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
