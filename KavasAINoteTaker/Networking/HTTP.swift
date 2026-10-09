import Foundation

/// Ağ istekleri için paylaşılan yapılandırma ve yeniden deneme yardımcıları.
enum HTTP {
    /// Uzun zaman aşımı: ASR/LLM uçları (özellikle soğuk model) 60 sn'yi aşabilir.
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600        // tek istek için 10 dk
        config.timeoutIntervalForResource = 3600      // toplam 1 saat
        config.waitsForConnectivity = true
        // Önbelleği kapat: güncelleme kontrolü hep taze yanıt almalı.
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    /// Geçici hatalarda (zaman aşımı, bağlantı, 5xx) birkaç kez yeniden dener.
    static func retry<T>(attempts: Int = 3,
                         initialDelay: Double = 2,
                         _ operation: () async throws -> T) async throws -> T {
        var delay = initialDelay
        var lastError: Error?
        for attempt in 1...attempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                guard isTransient(error), attempt < attempts else {
                    AppLog.error(error, "İstek \(attempt)/\(attempts) başarısız (yeniden deneme yok)")
                    throw error
                }
                AppLog.info("İstek \(attempt)/\(attempts) başarısız, \(Int(delay))s sonra yeniden denenecek: \(error.localizedDescription)")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay *= 2
            }
        }
        throw lastError ?? URLError(.unknown)
    }

    static func isTransient(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .cannotConnectToHost,
                 .notConnectedToInternet, .badServerResponse:
                return true
            default:
                return false
            }
        }
        if case ASRError.http(let code, _) = error { return code >= 500 || code == 429 }
        if case LLMError.http(let code, _) = error { return code >= 500 || code == 429 }
        // Boş/eksik yanıt geçici olabilir (uç soğukken veya anlık) → yeniden dene.
        if case LLMError.emptyResult = error { return true }
        if case LLMError.reasoningOnly = error { return true }
        if case ASRError.emptyResult = error { return true }
        return false
    }
}
