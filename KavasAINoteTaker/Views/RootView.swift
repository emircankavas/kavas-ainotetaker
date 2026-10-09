import SwiftUI

/// Uygulama kabuğu: solda ince ikon şeridi, sağda bölüm içeriği.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            SidebarRail()
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 920, minHeight: 620)
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
