import Foundation

/// Nihai toplantı özetini klasöre kaydeder.
enum SummaryIO {
    static func save(_ summary: String, folder: URL) throws {
        let url = folder.appendingPathComponent("summary.md")
        try summary.write(to: url, atomically: true, encoding: .utf8)
    }
}
