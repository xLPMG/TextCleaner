//
//  TextCleanerApp.swift
//  TextCleaner
//
//  Created by Luca-Philipp Grumbach on 21.12.25.
//
import SwiftUI
import SwiftData

@main
struct TextCleanerApp: App {
        
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .saveItem) {
                Button("Save Cleaned Image") {
                    NotificationCenter.default.post(
                        name: .saveImageCommand,
                        object: nil
                    )
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Open Image…") {
                    NotificationCenter.default.post(
                        name: .openImageCommand,
                        object: nil
                    )
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
