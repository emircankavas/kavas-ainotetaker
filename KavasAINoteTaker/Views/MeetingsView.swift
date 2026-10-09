import SwiftUI

/// Toplantılar bölümü: solda geçmiş listesi, sağda seçili toplantının detayı.
/// (meetily'nin "geniş kenar çubuğu + 3 panel" düzenine yakın.)
struct MeetingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            listPane
                .frame(width: 260)
                .background(Color(nsColor: .controlBackgroundColor))
            Divider()
            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { appState.refreshMeetings() }
    }

    // MARK: - List

    private var listPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Toplantı Notları").font(.headline)
                Spacer()
                Button {
                    appState.refreshMeetings()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Listeyi yenile")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

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
                        row(meeting).tag(meeting)
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    private func row(_ meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(meeting.name).font(.subheadline.weight(.medium)).lineLimit(1)
            HStack(spacing: 6) {
                Text(meeting.formattedDate).font(.caption).foregroundStyle(.secondary)
                if meeting.hasSummary {
                    Image(systemName: "doc.text.fill").font(.caption2).foregroundStyle(.green)
                } else if meeting.hasTranscript {
                    Image(systemName: "text.bubble").font(.caption2).foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        if let meeting = appState.selectedMeeting {
            MeetingDetailView(meeting: meeting)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 34))
                    .foregroundStyle(.tertiary)
                Text("Bir toplantı seçin")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
