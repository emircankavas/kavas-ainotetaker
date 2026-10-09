import SwiftUI

/// Uygulama günlüğünü gösteren pencere (hata ayıklama).
struct LogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Uygulama Günlüğü").font(.headline)
                Spacer()
                Button("Yenile") { reload() }
                Button("Finder'da Göster") {
                    NSWorkspace.shared.activateFileViewerSelecting([AppLog.fileURL])
                }
                Button("Kapat") { dismiss() }
            }
            .padding(12)
            Divider()
            ScrollView {
                Text(text.isEmpty ? "(günlük boş)" : text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
        .frame(width: 720, height: 520)
        .onAppear { reload() }
    }

    private func reload() { text = AppLog.tail(600) }
}
