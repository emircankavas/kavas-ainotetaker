import AVFoundation
import Foundation

/// AVAudioEngine ile mikrofonu (kendi sesinizi) kaydeder.
final class MicrophoneCapture {
    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private(set) var isRecording = false

    /// Mikrofon iznini ister (ilk kayıtta sistem diyaloğu).
    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start(to url: URL) throws {
        guard !isRecording else { return }
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            throw CaptureError.noMicrophone
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
        ]
        let audioFile = try AVAudioFile(forWriting: url,
                                        settings: settings,
                                        commonFormat: .pcmFormatFloat32,
                                        interleaved: false)
        file = audioFile

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self, let file = self.file else { return }
            try? file.write(from: buffer)
        }
        engine.prepare()
        try engine.start()
        isRecording = true
    }

    func stop() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file = nil
        isRecording = false
    }
}
