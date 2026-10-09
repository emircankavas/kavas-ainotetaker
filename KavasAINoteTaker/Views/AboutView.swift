import SwiftUI

/// Hakkında bölümü: sürüm bilgisi + güncelleme kontrolü.
struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @State private var showUpdate = false
    @State private var checking = false
    @State private var status: String?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 46))
                .foregroundStyle(Theme.record)
            Text("Kavas AI NoteTaker").font(.title.bold())
            Text("Sürüm \(UpdateChecker.currentVersion)").font(.callout).foregroundStyle(.secondary)
            Text("Online toplantı sesini kaydeder, Qwen3-ASR ile yazıya döker ve LLM ile özetler.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            HStack(spacing: 10) {
                Button {
                    showUpdate = true
                } label: {
                    Label("Güncellemeleri Kontrol Et", systemImage: "arrow.triangle.2.circlepath")
                }
                if checking { ProgressView().controlSize(.small) }
            }
            .padding(.top, 6)

            if let status {
                Text(status).font(.caption).foregroundStyle(.secondary)
            }

            Spacer().frame(height: 8)
            Text("© 2026 Emircan Kavas").font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .sheet(isPresented: $showUpdate) { UpdateView() }
        .task { await quickCheck() }
    }

    private func quickCheck() async {
        checking = true
        defer { checking = false }
        if let info = try? await UpdateChecker.check(), info.isNewer {
            status = "Yeni sürüm mevcut: \(info.latestVersion)"
        } else {
            status = "En son sürümü kullanıyorsunuz."
        }
    }
}
