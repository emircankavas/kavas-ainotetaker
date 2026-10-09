import AVFoundation
import Foundation

/// Basit enerji tabanlı VAD: büyüyen 16 kHz mono kayıtta, verilen örnekten sonra en az
/// `minGapSeconds` süren sessizlik boşluğunun BİTİŞ örneğini döndürür.
/// Canlı parçalama bu noktadan kesilir, böylece cümleler ortadan bölünmez (meetily yaklaşımı).
enum VAD {
    static func lastSilenceCut(inFile url: URL,
                               afterSample: Int,
                               minGapSeconds: Double = 1.5,
                               minSpeechSeconds: Double = 3.0,
                               threshold: Float = 0.008) -> Int? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        let total = Int(file.length)
        guard total > afterSample,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total)),
              let samples = buffer.floatChannelData?[0] else { return nil }
        try? file.read(into: buffer)

        let sampleRate = format.sampleRate
        let frame = max(1, Int(sampleRate * 0.1))
        let minGapFrames = max(1, Int((minGapSeconds * sampleRate) / Double(frame)))
        let minSpeech = Int(minSpeechSeconds * sampleRate)

        func isSilent(_ offset: Int) -> Bool {
            let start = max(0, offset)
            let end = min(total, offset + frame)
            guard end > start else { return true }
            var sum: Float = 0
            for i in start..<end { sum += samples[i] * samples[i] }
            return (sum / Float(end - start)).squareRoot() < threshold
        }

        var bestCut: Int?
        var runStart = -1
        var runLen = 0
        var offset = afterSample
        while offset + frame <= total {
            if isSilent(offset) {
                if runStart < 0 { runStart = offset }
                runLen += 1
            } else {
                if runLen >= minGapFrames {
                    let end = runStart + runLen * frame
                    if end - afterSample >= minSpeech { bestCut = end }
                }
                runStart = -1
                runLen = 0
            }
            offset += frame
        }
        if runLen >= minGapFrames {
            let end = runStart + runLen * frame
            if end - afterSample >= minSpeech { bestCut = end }
        }
        return bestCut
    }
}
