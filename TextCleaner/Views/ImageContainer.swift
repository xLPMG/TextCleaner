//
//  ImageContainer.swift
//  TextCleaner
//
//  Created by Luca-Philipp Grumbach on 22.12.25.
//
import SwiftUI

struct ImageContainer: View {
    let title: String
    let data: Data?

    var body: some View {
        VStack(spacing: 12) {
            if let data, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(minHeight: 250, maxHeight: 750)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.gray.opacity(0.2))
                    .frame(minHeight: 250, maxHeight: 750)
                    .overlay(Text("No \(title)"))
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 250, maxWidth: 500)
    }
}

#Preview {
    ImageContainer(title: "title", data: nil)
}
