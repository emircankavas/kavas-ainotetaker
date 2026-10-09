import Foundation

enum CaptureError: LocalizedError {
    case noApplicationSelected
    case tapCreation(OSStatus)
    case tapFormatUnavailable
    case tapUIDUnavailable
    case aggregateCreation(OSStatus)
    case ioProc(OSStatus)
    case deviceStart(OSStatus)
    case noMicrophone
    case formatConversion
    case microphoneDenied

    var errorDescription: String? {
        switch self {
        case .noApplicationSelected:
            return "Önce kaydedilecek uygulamayı seçin."
        case .tapCreation(let status):
            return "Ses yakalama tap'i oluşturulamadı (kod \(status)). Sistem Ayarları → Gizlilik → \"Sistem Ses Kaydı\" izni gerekebilir."
        case .tapFormatUnavailable:
            return "Tap ses formatı okunamadı."
        case .tapUIDUnavailable:
            return "Tap kimliği (UID) alınamadı."
        case .aggregateCreation(let status):
            return "Toplama ses cihazı oluşturulamadı (kod \(status))."
        case .ioProc(let status):
            return "Ses IO prosedürü kurulamadı (kod \(status))."
        case .deviceStart(let status):
            return "Ses cihazı başlatılamadı (kod \(status))."
        case .noMicrophone:
            return "Kullanılabilir mikrofon bulunamadı."
        case .formatConversion:
            return "Ses formatı AVAudioFormat'a dönüştürülemedi."
        case .microphoneDenied:
            return "Mikrofon izni verilmedi (Sistem Ayarları → Gizlilik → Mikrofon)."
        }
    }
}
