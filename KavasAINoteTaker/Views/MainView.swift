import SwiftUI

/// Kayıt paneli: uygulama seçimi, kaynak seçimi, kaydet/dur, transkript/özet, ilerleme.
struct MainView: View {
    @Environment(AppState.self) private var appState
    @AppStorage(SettingsKey.asrBaseURL) private var asrBaseURL = ""
    @AppStorage(SettingsKey.llmBaseURL) private var llmBaseURL = ""
    @AppStorage(SettingsKey.recordingsPath) private var recordingsPath = defaultRecordingsPath

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 16) {
            captureControls(state: $state)

            if let progress = appState.progress {
                ProgressView(value: progress)
            } else if appState.isBusy {
                ProgressView().progressViewStyle(.linear)
            }

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

            if let preview = appState.lastSummaryPreview {
                summaryPreview(preview)
            }

            configHint
        }
        .onAppear { appState.refreshProcesses() }
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

            Button {
                appState.summarizeLast()
            } label: {
                Label("Özet Çıkar", systemImage: "wand.and.stars")
            }
            .controlSize(.large)
            .disabled(!appState.canSummarize)

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

    private func summaryPreview(_ text: String) -> some View {
        ScrollView {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .frame(maxHeight: 160)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
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
