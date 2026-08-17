import SwiftUI

@main
struct TextToMP3App: App {
    @StateObject private var model = TTSViewModel()

    var body: some Scene {
        WindowGroup("Text to MP3") {
            ContentView(model: model)
        }
        .defaultSize(width: 1020, height: 740)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
            SpeechCommands(model: model)
        }
    }
}
