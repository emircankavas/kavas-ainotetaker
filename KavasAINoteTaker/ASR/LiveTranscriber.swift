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
    private var task: Task<Void, Never>?

    /// Periyodik olarak yeni ses parçasını işleyen döngüyü başlatır.
    /// - Parameters:
    ///   - folder: kayıt klasörü (app.caf / mic.caf buraya yazılıyor)
    ///   - client: ASR istemcisi
    ///   - language: dil ipucu ("auto" olabilir)
    ///   - interval: kontrol sıklığı (sn)
    ///   - minSeconds: bir parçayı göndermek için gereken en az yeni ses (sn)
    func start(folder: URL,
               client: ASRClient,
               language: String?,
               interval: Double = 5,
               minSeconds: Double = 5) {
        stop()
        lines = []
        isListening = true

        let sampleRate = AudioPreprocess.sampleRate
        let minFrames = Int(minSeconds * sampleRate)
        let appURL = folder.appendingPathComponent("app.caf")
        let micURL = folder.appendingPathComponent("mic.caf")
        let deltaURL = folder.appendingPathComponent("live_chunk.wav")
        let sendURL = folder.appendingPathComponent("live_chunk_send.wav")
        let fm = FileManager.default

        task = Task { [weak self] in
            var consumed = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard let self, !Task.isCancelled else { break }

                let appExists = fm.fileExists(atPath: appURL.path)
                let micExists = fm.fileExists(atPath: micURL.path)
                guard appExists || micExists else { continue }

                do {
                    let converted = try await Task.detached(priority: .utility) {
                        try AudioPreprocess.makeMixedWAV(appURL: appURL, micURL: micURL, outputURL: deltaURL)
                        return AudioFileInfo.frameCount(of: deltaURL)
                    }.value

                    guard converted - consumed >= minFrames else { continue }
                    try await Task.detached(priority: .utility) {
                        _ = try AudioPreprocess.slice(fromURL: deltaURL, startSample: consumed, toURL: sendURL)
                    }.value
                    consumed = converted

                    let text = try await client.transcribe(fileURL: sendURL, language: language)
                    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty {
                        self.lines.append(cleaned)
                    }
                } catch {
                    // Canlı transkript en iyi-çaba: sessizce yut.
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isListening = false
    }
}
