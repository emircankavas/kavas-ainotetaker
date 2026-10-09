import AVFoundation
import Foundation

/// Kayıt dosyalarını ASR girişi için işler: app.caf / mic.caf → 16 kHz mono WAV.
enum AudioPreprocess {
    static let sampleRate: Double = 16000

    static var targetFormat: AVAudioFormat {
        // Geçerli parametreler — her zaman oluşur.
        AVAudioFormat(commonFormat: .pcmFormatFloat32,
                      sampleRate: sampleRate,
                      channels: 1,
                      interleaved: false)!
    }

    /// 16-bit PCM WAV ayarları (ASR için standart giriş).
    static let wavSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: sampleRate,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
    ]

    /// Varsa app.caf + mic.caf dosyalarını 16 kHz mono olarak okuyup miksler ve `outputURL`'e yazar.
    static func makeMixedWAV(appURL: URL, micURL: URL, outputURL: URL) throws {
        let target = targetFormat
        var buffers: [AVAudioPCMBuffer] = []

        let fm = FileManager.default
        if fm.fileExists(atPath: appURL.path), let b = try readAndConvert(appURL, to: target) {
            buffers.append(b)
        }
        if fm.fileExists(atPath: micURL.path), let b = try readAndConvert(micURL, to: target) {
            buffers.append(b)
        }
        guard !buffers.isEmpty else { throw CaptureError.noAudioInput }

        let mixed = try mix(buffers, format: target)
        try? fm.removeItem(at: outputURL)
        let file = try AVAudioFile(forWriting: outputURL,
                                   settings: wavSettings,
                                   commonFormat: .pcmFormatFloat32,
                                   interleaved: false)
        try file.write(from: mixed)
    }

    /// Bir ses dosyasını okur ve hedef formata dönüştürür.
    static func readAndConvert(_ url: URL, to target: AVAudioFormat) throws -> AVAudioPCMBuffer? {
        let file = try AVAudioFile(forReading: url)
        let srcFormat = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: frameCount) else {
            return nil
        }
        try file.read(into: srcBuffer)

        guard let converter = AVAudioConverter(from: srcFormat, to: target) else {
            throw CaptureError.formatConversion
        }
        let ratio = target.sampleRate / srcFormat.sampleRate
        let outCapacity = AVAudioFrameCount(Double(frameCount) * ratio + 1024)
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: outCapacity) else {
            throw CaptureError.formatConversion
        }

        var error: NSError?
        var supplied = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if supplied {
                outStatus.pointee = .endOfStream
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return srcBuffer
        }
        converter.convert(to: outBuffer, error: &error, withInputFrom: inputBlock)
        if let error { throw error }
        return outBuffer
    }

    /// Float32 mono buffer'ları örnek-örnek toplayıp kaynak sayısına böler (ortalama miks).
    static func mix(_ buffers: [AVAudioPCMBuffer], format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let maxFrames = buffers.map { Int($0.frameLength) }.max() ?? 0
        guard maxFrames > 0,
              let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(maxFrames)),
              let outData = out.floatChannelData?[0] else {
            throw CaptureError.formatConversion
        }
        out.frameLength = AVAudioFrameCount(maxFrames)
        for i in 0..<maxFrames { outData[i] = 0 }

        var contributors = 0
        for buffer in buffers {
            guard let data = buffer.floatChannelData?[0] else { continue }
            let n = Int(buffer.frameLength)
            for i in 0..<n { outData[i] += data[i] }
            contributors += 1
        }
        if contributors > 1 {
            let divisor = Float(contributors)
            for i in 0..<maxFrames { outData[i] /= divisor }
        }
        return out
    }
}
