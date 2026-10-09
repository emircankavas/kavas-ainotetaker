import SwiftUI

@main
struct KavasAINoteTakerApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup("Kavas AI NoteTaker") {
            ContentView()
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environment(appState)
                .frame(width: 540)
        }
    }
}
