import SwiftUI

/// Ana yerleşim: solda toplantı listesi, sağda detay / kayıt paneli.
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @AppStorage(SettingsKey.recordingsPath) private var recordingsPath = defaultRecordingsPath

    var body: some View {
        NavigationSplitView {
            MeetingListView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            ScrollView {
                VStack(spacing: 20) {
                    MainView()
                    Divider()
                    if let meeting = appState.selectedMeeting {
                        MeetingDetailView(meeting: meeting)
                    } else {
                        Text("Soldan bir toplantı seçin veya yeni kayıt başlatın.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                }
                .padding(24)
            }
        }
        .onAppear { appState.refreshMeetings() }
    }
}
