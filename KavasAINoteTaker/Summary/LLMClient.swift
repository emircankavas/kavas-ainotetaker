import Foundation

/// LLM (sohbet tamamlama) istemcisi arayüzü.
protocol LLMClient: Sendable {
    func complete(system: String, user: String, maxTokens: Int) async throws -> String
}

enum LLMError: LocalizedError {
    case notConfigured
    case invalidURL(String)
    case invalidResponse
    case http(Int, String)
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Özet LLM endpoint'i ayarlanmamış. Ayarlar (⌘,) menüsünden girin."
        case .invalidURL(let value):
            return "Geçersiz LLM endpoint adresi: \(value)"
        case .invalidResponse:
            return "Özet sunucusundan geçersiz yanıt alındı."
        case .http(let code, let body):
            let detail = body.isEmpty ? "" : " — \(body.prefix(300))"
            return "Özet isteği başarısız (HTTP \(code))\(detail)"
        case .emptyResult:
            return "Özet modeli boş yanıt döndürdü."
        }
    }
}
