import Foundation
import Observation

/// Uygulamanın çalışma-zamanı durumu (kayıt/işleme akışı ileride buraya bağlanacak).
@Observable
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
    var statusText: String = "Ayarlardan endpoint ve API anahtarlarını girin."
    var lastError: String?

    var isBusy: Bool {
        phase == .recording || phase == .transcribing || phase == .summarizing
    }
}
