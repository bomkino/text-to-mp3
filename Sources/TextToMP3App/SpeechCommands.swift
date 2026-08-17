import SwiftUI

struct SpeechCommands: Commands {
    @ObservedObject var model: TTSViewModel

    var body: some Commands {
        CommandMenu("Speech") {
            Button("Open PDF or Text…", action: model.openDocumentPicker)
                .keyboardShortcut("o", modifiers: [.command])
                .disabled(!model.canImportDocument)

            Divider()

            Button("Generate MP3…", action: model.generate)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!model.canGenerate)

            Button("Cancel Generation", action: model.cancel)
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(!model.isGenerating)

            Divider()

            Button("Clear Text", action: model.clear)
                .keyboardShortcut("k", modifiers: [.command, .shift])
                .disabled(model.text.isEmpty || model.isGenerating || model.isImporting)

            Button("Show Last MP3 in Finder", action: model.revealLastOutput)
                .disabled(!model.canRevealLastOutput)
        }
    }
}
