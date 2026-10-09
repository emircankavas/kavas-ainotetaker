import AppKit
import SwiftUI

/// Seçili toplantının detayı: özet ve transkript sekmeleri + işlem düğmeleri.
struct MeetingDetailView: View {
    @Environment(AppState.self) private var appState
    let meeting: Meeting

    private enum Tab: String, CaseIterable { case summary = "Özet", transcript = "Transkript" }
    @State private var tab: Tab = .summary
    @State private var summaryText: String?
    @State private var transcript: Transcript?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if tab == .summary {
                if let summaryText {
                    textView(summaryText)
                } else {
                    placeholder("Bu toplantı için henüz özet yok.")
                }
            } else {
                if let transcript {
                    textView(Self.render(transcript))
                } else {
                    placeholder("Bu toplantı için henüz transkript yok.")
                }
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        .task(id: meeting.id) { load() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.name).font(.title3.bold())
                Text(meeting.formattedDate).font(.caption).foregroundStyle(.secondary)
                if let app = meeting.appName {
                    Text("Kaynak: \(app)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([meeting.folder])
            } label: {
                Label("Klasör", systemImage: "folder")
            }
            if !meeting.hasSummary {
                Button {
                    appState.processSelectedMeeting()
                } label: {
                    Label(meeting.hasTranscript ? "Özet Çıkar" : "Transkript + Özet Çıkar",
                          systemImage: "wand.and.stars")
                }
                .disabled(appState.isBusy)
            }
        }
    }

    private func textView(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .default))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func load() {
        summaryText = MeetingStore.loadSummary(folder: meeting.folder)
        transcript = MeetingStore.loadTranscript(folder: meeting.folder)
    }

    private static func render(_ transcript: Transcript) -> String {
        transcript.segments.map { segment in
            let total = Int(segment.start.rounded())
            let stamp = String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
            return "[\(stamp)] \(segment.text)"
        }.joined(separator: "\n\n")
    }
}
