import SwiftUI

@main
struct KavasAINoteTakerApp: App {
    @State private var appState = AppState()
    @State private var showLogs = false

    var body: some Scene {
        WindowGroup("Kavas AI NoteTaker") {
            RootView()
                .environment(appState)
                .sheet(isPresented: $showLogs) { LogView() }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Günlüğü Göster…") { showLogs = true }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
                .frame(width: 640, height: 560)
        }
    }
}
