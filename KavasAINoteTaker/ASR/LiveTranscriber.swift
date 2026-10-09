import AVFoundation
import Foundation
import Observation

/// Kayıt sürerken büyüyen ses dosyasından yeni kısımları, SESSİZLİK (VAD) sınırlarında
/// keserek ASR ucuna gönderir. Cümleler ortadan bölünmez; gecikme azalır.
/// (meetily'nin "1.5 sn sessizlik bekle" yaklaşımından uyarlanmıştır.)
@Observable
@MainActor
final class LiveTranscriber {
    private(set) var lines: [String] = []
    private(set) var isListening = false
    private(set) var status: String = "kapalı"
    private var task: Task<Void, Never>?

    func start(folder: URL,
               client: ASRClient,
               language: String?,
               pollInterval: Double = 4,
               minSpeechSeconds: Double = 3,
               silenceGapSeconds: Double = 1.2,
               maxPendingSeconds: Double = 22) {
        stop()
        lines = []
        isListening = true
        status = "başladı, konuşma bekleniyor…"

        let sampleRate = AudioPreprocess.sampleRate
        let minFrames = Int(minSpeechSeconds * sampleRate)
        let maxPending = Int(maxPendingSeconds * sampleRate)
        let appURL = folder.appendingPathComponent("app.caf")
        let micURL = folder.appendingPathComponent("mic.caf")
        let deltaURL = folder.appendingPathComponent("live_chunk.wav")
        let sendURL = folder.appendingPathComponent("live_chunk_send.wav")
        let fm = FileManager.default

        task = Task { [weak self] in
            var consumed = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                guard let self, !Task.isCancelled else { break }

                let appExists = fm.fileExists(atPath: appURL.path)
                let micExists = fm.fileExists(atPath: micURL.path)
                guard appExists || micExists else {
                    self.status = "ses dosyası bekleniyor…"
                    continue
                }

                do {
                    let converted = try await Task.detached(priority: .utility) {
                        try AudioPreprocess.makeMixedWAV(appURL: appURL, micURL: micURL, outputURL: deltaURL)
                        return AudioFileInfo.frameCount(of: deltaURL)
                    }.value

                    guard converted - consumed >= minFrames else {
                        self.status = "dinleniyor… \(self.lines.count) satır (konuşma bekleniyor)"
                        continue
                    }

                    // Sessizlik sınırında kes; sessizlik gelmezse çok uzarsa taşmayı önle.
                    let silenceCut = VAD.lastSilenceCut(inFile: deltaURL,
                                                        afterSample: consumed,
                                                        minGapSeconds: silenceGapSeconds,
                                                        minSpeechSeconds: minSpeechSeconds)
                    let cutPoint: Int
                    if let silenceCut {
                        cutPoint = min(silenceCut, converted)
                    } else if converted - consumed > maxPending {
                        cutPoint = converted - Int(0.3 * sampleRate) // son 0.3 sn'yi bırak
                        self.status = "sessizlik yok, uzun parça gönderiliyor…"
                    } else {
                        self.status = "dinleniyor… cümle sonu (sessizlik) bekleniyor"
                        continue
                    }
                    guard cutPoint > consumed else { continue }

                    try await Task.detached(priority: .utility) {
                        _ = try AudioPreprocess.slice(fromURL: deltaURL,
                                                      startSample: consumed,
                                                      toURL: sendURL,
                                                      endSample: cutPoint)
                    }.value
                    consumed = cutPoint

                    let text = try await client.transcribe(fileURL: sendURL, language: language)
                    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty {
                        self.lines.append(cleaned)
                        self.status = "dinleniyor… \(self.lines.count) satır"
                    } else {
                        self.status = "sessiz parça (boş sonuç)"
                    }
                } catch {
                    self.status = "hata: \(error.localizedDescription.prefix(140))"
                }
            }
        }
    }

    func setDisabled(_ reason: String) {
        lines = []
        isListening = false
        status = "başlatılamadı: \(reason)"
    }

    func clear() { lines = [] }

    func stop() {
        task?.cancel()
        task = nil
        isListening = false
        if status.hasPrefix("başladı") || status.hasPrefix("dinleniyor") || status.contains("bekleniyor") || status.contains("gönderiliyor") {
            status = "durdu"
        }
    }
}
