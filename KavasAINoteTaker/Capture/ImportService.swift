import AVFoundation
import Foundation

enum ImportError: LocalizedError {
    case noAudioTrack
    case exportFailed(String)
    case readFailed

    var errorDescription: String? {
        switch self {
        case .noAudioTrack: return "Dosyada ses parçası bulunamadı."
        case .exportFailed(let reason): return "Ses çıkarılamadı: \(reason)"
        case .readFailed: return "Dosya okunamadı."
        }
    }
}

/// İçe aktarılan ses/video dosyasından sesi ayıklayıp 16 kHz mono WAV üretir.
/// Hem ses dosyalarını hem de video (mp4/mov/mkv…) dosyalarını destekler.
enum ImportService {
    static func extractAudio(from source: URL, toWAV wavURL: URL) async throws {
        AppLog.info("Ses ayıklanıyor: \(source.lastPathComponent)")
        let target = AudioPreprocess.targetFormat

        // 1) Doğrudan ses dosyası olarak okunabiliyorsa (wav/mp3/m4a/aac…)
        if let buffer = try? AudioPreprocess.readAndConvert(source, to: target),
           buffer.frameLength > 0 {
            try writeWAV(buffer, to: wavURL)
            return
        }

        // 2) Video/diğer konteynerler: sesi m4a'ya export et, sonra oku.
        let asset = AVURLAsset(url: source)
        let audioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
        guard !audioTracks.isEmpty else { throw ImportError.noAudioTrack }

        let m4a = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")
        defer { try? FileManager.default.removeItem(at: m4a) }

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ImportError.exportFailed("dışa aktarma oturumu kurulamadı")
        }
        session.outputURL = m4a
        session.outputFileType = .m4a

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    cont.resume()
                case .cancelled:
                    cont.resume(throwing: ImportError.exportFailed("iptal edildi"))
                default:
                    cont.resume(throwing: ImportError.exportFailed(session.error?.localizedDescription ?? "bilinmeyen hata"))
                }
            }
        }

        guard let buffer = try AudioPreprocess.readAndConvert(m4a, to: target),
              buffer.frameLength > 0 else {
            throw ImportError.readFailed
        }
        try writeWAV(buffer, to: wavURL)
    }

    private static func writeWAV(_ buffer: AVAudioPCMBuffer, to url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        let file = try AVAudioFile(forWriting: url,
                                   settings: AudioPreprocess.wavSettings,
                                   commonFormat: .pcmFormatFloat32,
                                   interleaved: false)
        try file.write(from: buffer)
    }
}
