import Foundation
import Observation

/// Uygulamanın çalışma-zamanı durumu.
@Observable
@MainActor
final class AppState {
    enum Phase: String {
        case idle = "Hazır"
        case recording = "Kaydediliyor…"
        case transcribing = "Transkript çıkarılıyor…"
        case summarizing = "Özetleniyor…"
        case done = "Tamamlandı"
        case failed = "Hata"
    }

    var phase: Phase = .idle
    var statusText: String = "Ayarlardan endpoint ve API anahtarlarını girin, sonra bir uygulama seçin."
    var lastError: String?

    // Kayıt durumu
    var availableProcesses: [AudioProcess] = []
    var selectedProcess: AudioProcess?
    var captureSource: CaptureSource = .both

    private let coordinator = CaptureCoordinator()

    var isBusy: Bool {
        phase == .recording || phase == .transcribing || phase == .summarizing
    }

    func refreshProcesses() {
        availableProcesses = AudioProcessList.running()
        if let selected = selectedProcess, availableProcesses.contains(selected) {
            return
        }
        selectedProcess = availableProcesses.first
    }

    func startRecording(recordingsPath: String) {
        do {
            let folder = try coordinator.start(source: captureSource,
                                                process: selectedProcess,
                                                basePath: recordingsPath)
            phase = .recording
            lastError = nil
            statusText = "Kaydediliyor → \(folder.lastPathComponent)"
        } catch {
            phase = .failed
            lastError = error.localizedDescription
            statusText = "Kayıt başlatılamadı."
        }
    }

    func stopRecording() {
        coordinator.stop()
        phase = .idle
        statusText = "Kayıt durduruldu. (Transkript ve özet: sonraki fazlarda.)"
    }
}
