import AVFoundation
import Foundation

/// Kayıt dosyalarının büyüyen uzunluğunu (örnek cinsinden) okur.
enum AudioFileInfo {
    static func frameCount(of url: URL) -> Int {
        guard let file = try? AVAudioFile(forReading: url) else { return 0 }
        return Int(file.length)
    }
}
