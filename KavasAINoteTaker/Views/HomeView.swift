import AppKit
import SwiftUI

/// Ana sayfa: boşken karşılama, kayıtta canlı durum; altta yüzen kayıt kontrolü.
struct HomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack {
                Spacer()
                if appState.isRecording {
                    recordingState
                } else {
                    welcome
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            recordingPill
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var welcome: some View {
        VStack(spacing: 10) {
            Text("Kavas AI NoteTaker'a hoş geldiniz!")
                .font(.system(size: 26, weight: .bold))
            Text("Kaydı başlatınca toplantı sesi yakalanır ve işlenir.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.bottom, 60)
    }

    private var recordingState: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Circle().fill(Theme.record).frame(width: 9, height: 9)
                Text("Kaydediliyor • \(appState.elapsedText)")
                    .font(.system(.body, design: .rounded).weight(.medium))
                if appState.live.isListening {
                    Text("• Dinleniyor…")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(.quaternary.opacity(0.5), in: Capsule())

            if !appState.live.lines.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(appState.live.lines.enumerated()), id: \.offset) { _, line in
                            Text(line).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(14)
                }
                .frame(maxWidth: Theme.contentMaxWidth, maxHeight: 240)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            } else {
                Text(appState.live.isListening ? "Dinleniyor… ilk satırlar birazdan görünecek." : "Kayıt alınıyor.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 60)
    }

    private var recordingPill: some View {
        HStack(spacing: 0) {
            if appState.isRecording {
                pillButton(icon: "stop.fill", tint: Theme.record, label: "Kaydı durdur") {
                    appState.stopRecording()
                }
                .padding(.leading, 8)
                Spacer(minLength: 0)
                Image(systemName: "waveform")
                    .foregroundStyle(Theme.record)
                    .padding(.trailing, 20)
            } else {
                pillButton(icon: "mic.fill", tint: Theme.record, label: "Kaydı başlat") {
                    appState.startRecording(recordingsPath: SettingsStore.recordingsPath)
                }
                .padding(.leading, 8)
                Text("Kaydı başlat")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                Spacer(minLength: 0)
                sourceMenu
            }
        }
        .frame(width: 220, height: 52)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .disabled(appState.isBusy && !appState.isRecording)
    }

    private func pillButton(icon: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(tint).frame(width: 38, height: 38)
                Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .help(label)
    }

    private var sourceMenu: some View {
        @Bindable var state = appState
        return Menu {
            Picker("Kaynak", selection: $state.captureSource) {
                ForEach(CaptureSource.allCases) { source in
                    Text(source.label).tag(source)
                }
            }
            if appState.captureSource != .microphone {
                Divider()
                Menu("Uygulama: \(appState.selectedProcess?.name ?? "yok")") {
                    ForEach(appState.availableProcesses) { process in
                        Button(process.name) { state.selectedProcess = process }
                    }
                }
            }
            Divider()
            Button("Uygulama listesini yenile") { appState.refreshProcesses() }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 44)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
