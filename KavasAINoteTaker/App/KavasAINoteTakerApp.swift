import SwiftUI

@main
struct KavasAINoteTakerApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup("Kavas AI NoteTaker") {
            MainView()
                .environment(appState)
                .frame(minWidth: 760, minHeight: 520)
        }
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environment(appState)
                .frame(width: 520)
        }
    }
}
