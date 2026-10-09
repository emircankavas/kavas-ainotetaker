import Foundation

/// Endpoint erişilebilirliğini ve model listesini kontrol eder (Ayarlar'daki "Test Et").
enum EndpointTester {
    struct TestResult {
        let ok: Bool
        let message: String
    }

    /// OpenAI-uyumlu `GET {base}/models` çağrısı yapar.
    static func test(baseURL: String, apiKey: String) async -> TestResult {
        let trimmed = baseURL.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return TestResult(ok: false, message: "Endpoint boş.")
        }
        var s = trimmed
        while s.hasSuffix("/") { s.removeLast() }
        if !s.hasSuffix("/models") { s += "/models" }
        guard let url = URL(string: s) else {
            return TestResult(ok: false, message: "Geçersiz adres.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return TestResult(ok: false, message: "Geçersiz yanıt.")
            }
            guard (200..<300).contains(http.statusCode) else {
                return TestResult(ok: false, message: "HTTP \(http.statusCode).")
            }
            let models = parseModels(data)
            if models.isEmpty {
                return TestResult(ok: true, message: "Bağlantı OK (model listesi boş).")
            }
            let preview = models.prefix(5).joined(separator: ", ")
            return TestResult(ok: true, message: "Bağlantı OK — \(models.count) model: \(preview)")
        } catch {
            return TestResult(ok: false, message: error.localizedDescription)
        }
    }

    private static func parseModels(_ data: Data) -> [String] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        if let list = obj["data"] as? [[String: Any]] {
            return list.compactMap { $0["id"] as? String }
        }
        if let list = obj["models"] as? [[String: Any]] {
            return list.compactMap { $0["id"] as? String ?? $0["name"] as? String }
        }
        return []
    }
}
