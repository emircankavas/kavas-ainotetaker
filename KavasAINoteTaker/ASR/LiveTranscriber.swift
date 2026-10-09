import AVFoundation
import Foundation
import Observation

/// Kayıt sürerken büyüyen ses dosyasından yeni kısımları periyodik olarak ASR ucuna
/// gönderip "yaklaşık canlı" transkript üretir. Ayrı bir streaming protokolü gerektirmez;
/// mevcut OpenAI-uyumlu batch uç ile çalışır.
@Observable
@MainActor
final class LiveTranscriber {
    private(set) var lines: [String] = []
    private(set) var isListening = false
    private(set) var status: String = "kapalı"
    private var task: Task<Void, Never>?

    /// Periyodik olarak yeni ses parçasını işleyen döngüyü başlatır.
    func start(folder: URL,
               client: ASRClient,
               language: String?,
               interval: Double = 5,
               minSeconds: Double = 5) {
        stop()
        lines = []
        isListening = true
        status = "başladı, ilk parça bekleniyor…"

        let sampleRate = AudioPreprocess.sampleRate
        let minFrames = Int(minSeconds * sampleRate)
        let appURL = folder.appendingPathComponent("app.caf")
        let micURL = folder.appendingPathComponent("mic.caf")
        let deltaURL = folder.appendingPathComponent("live_chunk.wav")
        let sendURL = folder.appendingPathComponent("live_chunk_send.wav")
        let fm = FileManager.default

        task = Task { [weak self] in
            var consumed = 0
            var emptyPolls = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard let self, !Task.isCancelled else { break }

                let appExists = fm.fileExists(atPath: appURL.path)
                let micExists = fm.fileExists(atPath: micURL.path)
                if !appExists && !micExists {
                    emptyPolls += 1
                    self.status = "ses dosyası bekleniyor… (#\(emptyPolls))"
                    continue
                }

                do {
                    let converted = try await Task.detached(priority: .utility) {
                        try AudioPreprocess.makeMixedWAV(appURL: appURL, micURL: micURL, outputURL: deltaURL)
                        return AudioFileInfo.frameCount(of: deltaURL)
                    }.value

                    if converted == 0 {
                        emptyPolls += 1
                        self.status = "kayıt dosyası okunamıyor (0 uzunluk) — #\(emptyPolls)"
                        continue
                    }

                    guard converted - consumed >= minFrames else {
                        self.status = "dinleniyor… \(self.lines.count) satır (yeni ses bekleniyor)"
                        continue
                    }

                    try await Task.detached(priority: .utility) {
                        _ = try AudioPreprocess.slice(fromURL: deltaURL, startSample: consumed, toURL: sendURL)
                    }.value
                    consumed = converted

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

    /// Canlı transkript başlatılamadığında nedeni göster.
    func setDisabled(_ reason: String) {
        lines = []
        isListening = false
        status = "başlatılamadı: \(reason)"
    }

    func stop() {
        task?.cancel()
        task = nil
        isListening = false
        if status.hasPrefix("başladı") || status.hasPrefix("dinleniyor") || status.contains("bekleniyor") {
            status = "durdu"
        }
    }
}
