import SwiftUI

/// Güncelleme penceresi: yeni sürüm varsa changelog ve "Güncelle" düğmesi.
struct UpdateView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .checking
    @State private var info: UpdateInfo?
    @State private var message: String?

    enum Phase { case checking, upToDate, available, installing, done, failed }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Güncellemeler").font(.headline)
                Spacer()
                if phase != .installing {
                    Button("Kapat") { dismiss() }
                }
            }
            .padding(12)
            Divider()

            content
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 560, height: 460)
        .task { await check() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .checking:
            centered { ProgressView("Kontrol ediliyor…") }

        case .upToDate:
            centered {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 40)).foregroundStyle(.green)
                    Text("En son sürümü kullanıyorsunuz.")
                    Text("Sürüm \(UpdateChecker.currentVersion)").foregroundStyle(.secondary)
                }
            }

        case .available, .installing, .failed:
            VStack(alignment: .leading, spacing: 12) {
                if let info {
                    HStack(alignment: .firstTextBaseline) {
                        Text(info.name).font(.title3.bold())
                        Text("(\(info.currentVersion) → \(info.latestVersion))")
                            .foregroundStyle(.secondary)
                    }
                    ScrollView {
                        Text(info.notes.isEmpty ? "(Sürüm notu yok.)" : info.notes)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 240)
                    .padding(10)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }

                if let message {
                    Text(message).font(.caption).foregroundStyle(.red)
                }

                HStack {
                    if phase == .installing {
                        ProgressView().controlSize(.small)
                        Text("İndiriliyor ve uygulanıyor…").foregroundStyle(.secondary)
                    } else {
                        Button("Güncelle ve Yeniden Başlat") { install() }
                            .buttonStyle(.borderedProminent)
                    }
                    if let url = info.flatMap({ URL(string: $0.htmlURL) }) {
                        Button("Sürüm Notlarını Aç") { NSWorkspace.shared.open(url) }
                    }
                }
            }
        case .done:
            centered { Text("Güncellendi. Uygulama yeniden başlatılıyor…") }
        }
    }

    private func centered<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        content().frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func check() async {
        phase = .checking
        do {
            if let result = try await UpdateChecker.check() {
                info = result
                phase = result.isNewer ? .available : .upToDate
            } else {
                phase = .failed
                message = "Güncelleme bilgisi alınamadı."
            }
        } catch {
            phase = .failed
            message = error.localizedDescription
        }
    }

    private func install() {
        guard let info else { return }
        phase = .installing
        Task {
            do {
                try await UpdateService.downloadAndInstall(info)
                phase = .done
            } catch {
                phase = .failed
                message = error.localizedDescription
                AppLog.error(error, "Güncelleme uygulanamadı")
            }
        }
    }
}
