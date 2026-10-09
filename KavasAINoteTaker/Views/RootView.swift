import SwiftUI
import UniformTypeIdentifiers

/// Uygulama kabuğu: solda ince ikon şeridi, sağda bölüm içeriği.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var showImporter = false

    var body: some View {
        HStack(spacing: 0) {
            SidebarRail(onImport: { showImporter = true })
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 920, minHeight: 620)
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.audio, .movie, .mpeg4Movie, .quickTimeMovie],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                appState.importFile(url)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appState.section {
        case .home: HomeView()
        case .meetings: MeetingsView()
        case .settings: SettingsView()
        case .about: AboutView()
        }
    }
}
