import Foundation

/// OpenAI-uyumlu `/v1/chat/completions` ucuna istek atan LLM istemcisi.
/// DeepSeek / OpenAI / yerel uçlarla çalışır (model ve endpoint ayarlardan gelir).
/// Uzun zaman aşımı + geçici hatalarda otomatik yeniden deneme içerir.
struct OpenAICompatLLMClient: LLMClient {
    let baseURL: String
    let apiKey: String
    let model: String
    let temperature: Double

    init(baseURL: String, apiKey: String, model: String, temperature: Double = 0.2) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
    }

    func complete(system: String, user: String, maxTokens: Int) async throws -> String {
        guard !baseURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw LLMError.notConfigured
        }
        let endpoint = try Self.endpoint(from: baseURL)

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": false,
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)

        return try await HTTP.retry {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 600
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            request.httpBody = body

            let (data, response) = try await HTTP.session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw LLMError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                throw LLMError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
            }
            AppLog.info("LLM ham yanıt (\(data.count) bayt): \(Self.snippet(data))")
            guard let content = Self.extractContent(from: data),
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LLMError.emptyResult
            }
            return content
        }
    }

    /// Log için ham yanıt özeti.
    static func snippet(_ data: Data) -> String {
        let text = String(data: data, encoding: .utf8) ?? "<binary>"
        let flat = text.replacingOccurrences(of: "\n", with: " ")
        return flat.count > 800 ? String(flat.prefix(800)) + "…" : flat
    }

    // MARK: - Helpers

    static func endpoint(from base: String) throws -> URL {
        var s = base.trimmingCharacters(in: .whitespaces)
        while s.hasSuffix("/") { s.removeLast() }
        if !s.hasSuffix("/chat/completions") {
            s += "/chat/completions"
        }
        guard let url = URL(string: s) else { throw LLMError.invalidURL(base) }
        return url
    }

    static func extractContent(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let first = choices.first else { return nil }
        if let message = first["message"] as? [String: Any] {
            // Bazı OpenAI-uyumlu uçlar/reasoning modelleri metni farklı alanlarda döndürür.
            for key in ["content", "reasoning_content", "reasoning", "text"] {
                if let value = message[key] as? String,
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return value
                }
            }
        }
        if let text = first["text"] as? String { return text }
        return nil
    }
}
