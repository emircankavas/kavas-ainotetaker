import SwiftUI

/// Sol kenar çubuğu: toplantı listesi.
struct MeetingListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List(selection: Binding(
            get: { appState.selectedMeeting },
            set: { if let meeting = $0 { appState.selectMeeting(meeting) } }
        )) {
            if appState.meetings.isEmpty {
                Text("Henüz toplantı yok.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(appState.meetings) { meeting in
                    row(meeting)
                        .tag(meeting)
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem {
                Button {
                    appState.refreshMeetings()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Listeyi yenile")
            }
        }
        .navigationTitle("Toplantılar")
    }

    private func row(_ meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(meeting.name)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(meeting.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if meeting.hasSummary {
                    Image(systemName: "doc.text.fill").foregroundStyle(.green)
                } else if meeting.hasTranscript {
                    Image(systemName: "text.bubble").foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
