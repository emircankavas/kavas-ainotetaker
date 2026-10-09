import SwiftUI

@main
struct KavasAINoteTakerApp: App {
    @State private var appState = AppState()
    @State private var updateState = UpdateState()
    @State private var showLogs = false
    @State private var showUpdate = false

    var body: some Scene {
        WindowGroup("Kavas AI NoteTaker") {
            RootView()
                .environment(appState)
                .environment(updateState)
                .task { updateState.checkOnLaunch() }
                .sheet(isPresented: $showLogs) { LogView() }
                .sheet(isPresented: $showUpdate) { UpdateView() }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Güncellemeleri Kontrol Et…") { showUpdate = true }
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
