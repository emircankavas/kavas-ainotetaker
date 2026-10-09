import AppKit
import SwiftUI

/// Ana pencere: uygulama seçimi, kaynak seçimi, kaydet/dur, transkript çıkar.
struct MainView: View {
    @Environment(AppState.self) private var appState
    @AppStorage(SettingsKey.asrBaseURL) private var asrBaseURL = ""
    @AppStorage(SettingsKey.llmBaseURL) private var llmBaseURL = ""
    @AppStorage(SettingsKey.recordingsPath) private var recordingsPath = defaultRecordingsPath

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 16) {
            header
            Divider()

            captureControls(state: $state)

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
                    .textSelection(.enabled)
            }

            actionButtons

            Spacer()
            configHint
        }
        .padding(24)
        .onAppear { appState.refreshProcesses() }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Kavas AI NoteTaker").font(.title.bold())
            Text("Toplantı sesi → transkript → özet")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func captureControls(state: Bindable<AppState>) -> some View {
        VStack(spacing: 10) {
            Picker("Kaynak", selection: state.captureSource) {
                ForEach(CaptureSource.allCases) { source in
                    Text(source.label).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .disabled(appState.isBusy)

            if appState.captureSource != .microphone {
                HStack {
                    Picker("Uygulama", selection: state.selectedProcess) {
                        if appState.availableProcesses.isEmpty {
                            Text("Ses çıkışı olan uygulama yok").tag(AudioProcess?.none)
                        }
                        ForEach(appState.availableProcesses) { process in
                            Text(process.name).tag(AudioProcess?.some(process))
                        }
                    }
                    .disabled(appState.isBusy)

                    Button {
                        appState.refreshProcesses()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Uygulama listesini yenile")
                    .disabled(appState.isBusy)
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                appState.startRecording(recordingsPath: recordingsPath)
            } label: {
                Label("Kaydı Başlat", systemImage: "record.circle")
            }
            .controlSize(.large)
            .disabled(appState.isBusy)

            Button {
                appState.stopRecording()
            } label: {
                Label("Durdur", systemImage: "stop.circle")
            }
            .controlSize(.large)
            .disabled(!appState.isBusy)

            Button {
                appState.transcribeLast()
            } label: {
                Label("Transkript Çıkar", systemImage: "text.bubble")
            }
            .controlSize(.large)
            .disabled(!appState.canTranscribe)

            if let folder = appState.lastFolder {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([folder])
                } label: {
                    Image(systemName: "folder")
                }
                .help("Kayıt klasörünü Finder'da aç")
            }
        }
    }

    private var configHint: some View {
        Group {
            if asrBaseURL.isEmpty || llmBaseURL.isEmpty {
                Label("Endpoint'ler yapılandırılmadı — Ayarlar (⌘,) menüsünden girin.",
                      systemImage: "exclamationmark.triangle")
                    .font(.footnote).foregroundStyle(.orange)
            } else {
                Label("Yapılandırma hazır.", systemImage: "checkmark.circle")
                    .font(.footnote).foregroundStyle(.green)
            }
        }
    }
}
