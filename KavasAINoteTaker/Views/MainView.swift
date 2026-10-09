import SwiftUI

/// Ana pencere. Şimdilik iskelet: durum + kaydet/dur düğmeleri (Faz 1'de Capture'a bağlanacak).
struct MainView: View {
    @Environment(AppState.self) private var appState
    @AppStorage(SettingsKey.asrBaseURL) private var asrBaseURL = ""
    @AppStorage(SettingsKey.llmBaseURL) private var llmBaseURL = ""

    var body: some View {
        VStack(spacing: 16) {
            header

            Divider()

            Text(appState.statusText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            if let err = appState.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button {
                    // Faz 1'de CaptureCoordinator'a bağlanacak.
                } label: {
                    Label("Kaydı Başlat", systemImage: "record.circle")
                }
                .controlSize(.large)
                .disabled(appState.isBusy)

                Button {
                    // Faz 1'de duracak.
                } label: {
                    Label("Durdur", systemImage: "stop.circle")
                }
                .controlSize(.large)
                .disabled(!appState.isBusy)
            }

            Spacer()

            configHint
        }
        .padding(24)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Kavas AI NoteTaker")
                .font(.title.bold())
            Text("Toplantı sesi → transkript → özet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var configHint: some View {
        Group {
            if asrBaseURL.isEmpty || llmBaseURL.isEmpty {
                Label("Endpoint'ler yapılandırılmadı — Ayarlar (⌘,) menüsünden girin.",
                      systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else {
                Label("Yapılandırma hazır.", systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        }
    }
}
