import Foundation

/// Bir toplantı klasörünün üst-verisi (meta.json).
struct MeetingMeta: Codable {
    var name: String
    var createdAt: Date
    var appName: String?
    var source: String?
    var durationSeconds: Double?
    var asrModel: String?
    var llmModel: String?
}

/// Bir toplantı kaydı (klasör + türev çıktıların varlığı).
struct Meeting: Identifiable, Hashable {
    let folder: URL
    var name: String
    var createdAt: Date
    var appName: String?
    var hasTranscript: Bool
    var hasSummary: Bool

    var id: URL { folder }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}
