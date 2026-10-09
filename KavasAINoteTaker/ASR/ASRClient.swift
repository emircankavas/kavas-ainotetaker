import Foundation

/// ASR istemcisi arayüzü. Tek dosyayı metne çevirir.
protocol ASRClient: Sendable {
    func transcribe(fileURL: URL, language: String?) async throws -> String
}

/// Transkriptin bir parçası (zaman damgalı).
struct TranscriptSegment: Codable, Sendable {
    let index: Int
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}

/// Tam transkript.
struct Transcript: Codable, Sendable {
    var segments: [TranscriptSegment]
    var language: String?
    var fullText: String
    var createdAt: Date
}

enum ASRError: LocalizedError {
    case notConfigured
    case invalidURL(String)
    case invalidResponse
    case http(Int, String)
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "ASR endpoint'i ayarlanmamış. Ayarlar (⌘,) menüsünden girin."
        case .invalidURL(let value):
            return "Geçersiz ASR endpoint adresi: \(value)"
        case .invalidResponse:
            return "ASR sunucusundan geçersiz yanıt alındı."
        case .http(let code, let body):
            let detail = body.isEmpty ? "" : " — \(body.prefix(300))"
            return "ASR isteği başarısız (HTTP \(code))\(detail)"
        case .emptyResult:
            return "ASR boş sonuç döndürdü."
        }
    }
}
