import Foundation

/// Transkripti toplantı klasörüne kaydeder (JSON + okunabilir TXT).
enum TranscriptIO {
    static func save(_ transcript: Transcript, to folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(transcript)
        try json.write(to: folder.appendingPathComponent("transcript.json"))

        var lines: [String] = []
        for segment in transcript.segments {
            lines.append("[\(timestamp(segment.start)) - \(timestamp(segment.end))] \(segment.text)")
        }
        let txt = lines.joined(separator: "\n")
        try txt.write(to: folder.appendingPathComponent("transcript.txt"),
                      atomically: true, encoding: .utf8)
    }

    private static func timestamp(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
