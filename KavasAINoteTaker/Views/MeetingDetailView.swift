import AppKit
import SwiftUI

/// Seçili toplantının detayı: solda transkript, sağda özet (meetily tarzı iki panel).
struct MeetingDetailView: View {
    @Environment(AppState.self) private var appState
    let meeting: Meeting

    @State private var summaryText: String?
    @State private var transcript: Transcript?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                transcriptPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                summaryPane
                    .frame(width: 340)
                    .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .task(id: meeting.id) { load() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.name).font(.title3.bold())
                HStack(spacing: 8) {
                    Text(meeting.formattedDate).font(.caption).foregroundStyle(.secondary)
                    if let app = meeting.appName {
                        Text("· \(app)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if !meeting.hasSummary {
                Button {
                    appState.processSelectedMeeting()
                } label: {
                    Label(meeting.hasTranscript ? "Özet Üret" : "Transkript + Özet Üret",
                          systemImage: "wand.and.stars")
                }
                .disabled(appState.isBusy)
            }
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([meeting.folder])
            } label: {
                Label("Klasör", systemImage: "folder")
            }
        }
        .padding(14)
    }

    private var transcriptPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Transkript").font(.headline)
                Spacer()
                if transcript != nil {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(Self.render(transcript!), forType: .string)
                    } label: {
                        Label("Kopyala", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Divider()

            if let transcript {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(transcript.segments, id: \.index) { segment in
                            HStack(alignment: .top, spacing: 10) {
                                Text("[\(Self.stamp(segment.start))]")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text(segment.text)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
            } else {
                placeholder("Bu toplantı için henüz transkript yok.")
            }
        }
    }

    private var summaryPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Özet").font(.headline)
                Spacer()
                if summaryText != nil {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(summaryText ?? "", forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Özeti kopyala")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Divider()

            if let summaryText {
                ScrollView {
                    Text(summaryText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles").font(.system(size: 28)).foregroundStyle(.tertiary)
                    Text("Henüz özet üretilmedi.")
                        .foregroundStyle(.secondary)
                    if meeting.hasTranscript {
                        Button("Özet Üret") { appState.processSelectedMeeting() }
                            .buttonStyle(.borderedProminent)
                            .disabled(appState.isBusy)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func load() {
        summaryText = MeetingStore.loadSummary(folder: meeting.folder)
        transcript = MeetingStore.loadTranscript(folder: meeting.folder)
    }

    static func stamp(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    static func render(_ transcript: Transcript) -> String {
        transcript.segments.map { "[\(stamp($0.start))] \($0.text)" }.joined(separator: "\n")
    }
}
