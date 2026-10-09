import AppKit
import SwiftUI
/// Her bölümün altında görünen global durum çubuğu: işlem ilerlemesi, hatalar.
/// Uygulamanın "çalışıyor mu, dondu mu?" sorusunu yanıtlar.
struct StatusBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 8) {
            indicator
            Text(appState.statusText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if let err = appState.lastError {
                Text("•").foregroundStyle(.tertiary)
                Text(err).font(.caption).foregroundStyle(.red).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([AppLog.fileURL])
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Günlük dosyasını Finder'da göster")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    @ViewBuilder
    private var indicator: some View {
        switch appState.phase {
        case .recording, .transcribing, .summarizing:
            ProgressView().controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.record)
        case .idle:
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundStyle(.tertiary)
        }
    }
}
