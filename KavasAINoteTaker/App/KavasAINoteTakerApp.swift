import SwiftUI

@main
struct KavasAINoteTakerApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup("Kavas AI NoteTaker") {
            RootView()
                .environment(appState)
        }
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environment(appState)
                .frame(width: 640, height: 560)
        }
    }
}
