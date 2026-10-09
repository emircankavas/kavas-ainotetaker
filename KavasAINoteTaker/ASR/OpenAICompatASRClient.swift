import Foundation

/// OpenAI-uyumlu `/v1/audio/transcriptions` ucuna multipart istek atan ASR istemcisi.
/// Qwen3-ASR-1.7B (vLLM / qwen-asr-serve) gibi uçlarla çalışır.
struct OpenAICompatASRClient: ASRClient {
    let baseURL: String
    let apiKey: String
    let model: String

    func transcribe(fileURL: URL, language: String?) async throws -> String {
        guard !baseURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ASRError.notConfigured
        }
        let endpoint = try Self.endpoint(from: baseURL)
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try Self.multipartBody(boundary: boundary,
                                                  model: model,
                                                  fileURL: fileURL,
                                                  language: language)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ASRError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ASRError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        let text = Self.extractText(from: data)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ASRError.emptyResult
        }
        return Self.stripLanguagePrefix(text)
    }

    // MARK: - Helpers

    /// Base URL'den transkript uç noktasını üretir. Girdi `https://host/v1` beklenir.
    static func endpoint(from base: String) throws -> URL {
        var s = base.trimmingCharacters(in: .whitespaces)
        while s.hasSuffix("/") { s.removeLast() }
        if !s.hasSuffix("/audio/transcriptions") {
            s += "/audio/transcriptions"
        }
        guard let url = URL(string: s) else { throw ASRError.invalidURL(base) }
        return url
    }

    static func multipartBody(boundary: String, model: String, fileURL: URL, language: String?) throws -> Data {
        var body = Data()
        func append(_ string: String) { body.append(Data(string.utf8)) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        append("\(model)\r\n")

        if let language, !language.isEmpty, language != "auto" {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            append("\(language)\r\n")
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
        append("json\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        append("Content-Type: audio/wav\r\n\r\n")
        body.append(try Data(contentsOf: fileURL))
        append("\r\n")

        append("--\(boundary)--\r\n")
        return body
    }

    /// Yanıttan metni çıkarır: önce `text`, sonra `segments[].text`, en son ham gövde.
    static func extractText(from data: Data) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let text = obj["text"] as? String { return text }
            if let segments = obj["segments"] as? [[String: Any]] {
                return segments.compactMap { $0["text"] as? String }.joined(separator: " ")
            }
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Qwen3-ASR'ın eklediği `language X\n` ön ekini temizler.
    static func stripLanguagePrefix(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: "^language [A-Za-z]+\\s*\\n", options: .regularExpression) {
            return String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
}
