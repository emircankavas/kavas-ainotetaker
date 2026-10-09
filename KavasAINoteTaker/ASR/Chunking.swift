import AVFoundation
import Foundation

/// Uzun sesi ASR süre limitini aşmamak için sessizliklerde parçalara böler.
///
/// Basit RMS tabanlı VAD: 100 ms'lik çerçevelerde ses seviyesine bakar, hedef
/// süreye yaklaşınca en yakın sessizlik noktasından keser (cümle ortasında bölmemek için).
enum Chunking {
    struct Chunk: Sendable {
        let url: URL
        let start: TimeInterval
        let end: TimeInterval
    }

    static func split(wavURL: URL,
                      targetSeconds: Double,
                      outDir: URL,
                      silenceThreshold: Float = 0.008) throws -> [Chunk] {
        let file = try AVAudioFile(forReading: wavURL)
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let totalFrames = Int(file.length)
        guard totalFrames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames)),
              let samples = buffer.floatChannelData?[0] else {
            throw ASRError.emptyResult
        }
        try file.read(into: buffer)

        let frameLen = max(1, Int(sampleRate * 0.1))          // 100 ms
        let targetFrames = max(1, Int(targetSeconds * sampleRate))
        let searchWindow = max(1, Int(15 * sampleRate))        // hedefin ±15 sn çevresinde sessizlik ara

        // Sessiz çerçeve indeksleri (örnek ofseti).
        func isSilent(atFrames offset: Int) -> Bool {
            let start = max(0, offset)
            let end = min(totalFrames, offset + frameLen)
            guard end > start else { return true }
            var sum: Float = 0
            for i in start..<end { sum += samples[i] * samples[i] }
            let rms = (sum / Float(end - start)).squareRoot()
            return rms < silenceThreshold
        }

        func nearestSilence(around target: Int) -> Int {
            guard target < totalFrames else { return totalFrames }
            let lo = max(0, target - searchWindow)
            let hi = min(totalFrames, target + searchWindow)
            var best: (offset: Int, distance: Int)?
            var offset = lo
            while offset < hi {
                if isSilent(atFrames: offset) {
                    let distance = abs(offset - target)
                    if best == nil || distance < best!.distance {
                        best = (offset + frameLen / 2, distance)
                    }
                }
                offset += frameLen
            }
            return best?.offset ?? target
        }

        // Kesim noktalarını belirle.
        var cuts: [Int] = [0]
        var cursor = targetFrames
        while cursor < totalFrames {
            let cut = nearestSilence(around: cursor)
            if cut <= cuts.last! { cursor += targetFrames; continue }
            cuts.append(min(cut, totalFrames))
            cursor = cut + targetFrames
        }
        cuts.append(totalFrames)

        // Parçaları yaz.
        var chunks: [Chunk] = []
        for i in 0..<(cuts.count - 1) {
            let start = cuts[i]
            let end = cuts[i + 1]
            guard end > start else { continue }
            let frames = end - start
            guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
                  let outData = out.floatChannelData?[0] else { continue }
            out.frameLength = AVAudioFrameCount(frames)
            outData.update(from: samples.advanced(by: start), count: frames)

            let chunkURL = outDir.appendingPathComponent(String(format: "chunk_%03d.wav", chunks.count))
            try? FileManager.default.removeItem(at: chunkURL)
            let writer = try AVAudioFile(forWriting: chunkURL,
                                         settings: AudioPreprocess.wavSettings,
                                         commonFormat: .pcmFormatFloat32,
                                         interleaved: false)
            try writer.write(from: out)

            chunks.append(Chunk(url: chunkURL,
                                start: Double(start) / sampleRate,
                                end: Double(end) / sampleRate))
        }
        return chunks
    }
}
