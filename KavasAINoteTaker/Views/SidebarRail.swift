import SwiftUI

/// Soldaki ince ikon şeridi: logo, gezinme, kayıt, içe aktar, ayarlar, hakkında.
/// Hakkında düğmesinde güncelleme varsa kırmızı rozet gösterilir.
struct SidebarRail: View {
    @Environment(AppState.self) private var appState
    @Environment(UpdateState.self) private var update
    var onImport: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "pencil.and.outline")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 12)
                .padding(.bottom, 6)

            navButton(.home)
            navButton(.meetings)

            recordButton
            importButton

            Spacer()

            navButton(.settings)
            navButton(.about)
                .padding(.bottom, 12)
        }
        .frame(width: Theme.railWidth)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private func navButton(_ section: AppState.Section) -> some View {
        let selected = appState.section == section
        return Button {
            appState.section = section
        } label: {
            Image(systemName: selected ? section.iconFilled : section.icon)
                .font(.system(size: 17, weight: .regular))
                .frame(width: 40, height: 36)
                .foregroundStyle(selected ? Theme.accent : Color.secondary)
                .background(selected ? Theme.selection : .clear,
                            in: RoundedRectangle(cornerRadius: 9))
                .overlay(alignment: .topTrailing) {
                    if section == .about, update.available != nil {
                        Circle().fill(Theme.record).frame(width: 8, height: 8)
                            .offset(x: -4, y: 4)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(section.title)
    }

    private var recordButton: some View {
        Button {
            if appState.isRecording {
                appState.stopRecording()
            } else {
                appState.startRecording(recordingsPath: SettingsStore.recordingsPath)
            }
        } label: {
            ZStack {
                Circle().fill(Theme.record).frame(width: 40, height: 40)
                Image(systemName: appState.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(appState.isBusy && !appState.isRecording)
        .help(appState.isRecording ? "Kaydı durdur" : "Kaydı başlat")
    }

    private var importButton: some View {
        Button {
            onImport()
        } label: {
            ZStack {
                Circle().fill(Theme.accent).frame(width: 40, height: 40)
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(appState.isBusy)
        .help("Ses/video içe aktar")
    }
}
