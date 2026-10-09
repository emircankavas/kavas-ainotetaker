import Foundation

/// Basit, kalıcı dosya günlüğü. Kayıt/içe aktarma/transkript/özet ve ağ olaylarını
/// `~/Library/Application Support/KavasAINoteTaker/logs/app.log` dosyasına yazar.
/// (Application Support TCC korumalı değildir → klasör izni sorulmaz.)
enum AppLog {
    private static let queue = DispatchQueue(label: "com.emircankavas.KavasAINoteTaker.log")
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("KavasAINoteTaker/logs", isDirectory: true)
    }

    static var fileURL: URL { directory.appendingPathComponent("app.log") }

    static func info(_ message: String) { write("INFO", message) }
    static func error(_ message: String) { write("ERROR", message) }
    static func error(_ error: Error, _ context: String) {
        write("ERROR", "\(context): \(error.localizedDescription)")
    }

    private static func write(_ level: String, _ message: String) {
        let line = "\(formatter.string(from: Date())) [\(level)] \(message)\n"
        print(line, terminator: "") // Xcode/console için
        queue.async {
            let fm = FileManager.default
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                if let data = line.data(using: .utf8) { handle.write(data) }
            } else {
                try? line.data(using: .utf8)?.write(to: fileURL)
            }
        }
    }

    /// Son N satırı döndürür (arayüzde gösterim için).
    static func tail(_ maxLines: Int = 400) -> String {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return "" }
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        return lines.suffix(maxLines).joined(separator: "\n")
    }
}
