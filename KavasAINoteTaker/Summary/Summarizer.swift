import Foundation

/// Transkriptten toplantı özeti üretir (map-reduce). Uzun transkriptleri parçalayıp
/// önce kısmi özet (map), sonra birleşik nihai özet (reduce) çıkarır.
enum Summarizer {
    /// Karakter eşiği: bunun altındaki transkript tek seferde özetlenir.
    static let mapChunkChars = 12_000
    /// Yüksek token bütçesi: reasoning modelleri düşünme için token harcar; düşük bütçede
    /// nihai cevaba (content) yer kalmayabiliyor.
    static let maxOutputTokens = 8_000

    static func run(folder: URL,
                    transcript: Transcript,
                    client: LLMClient) async throws -> String {
        let text = renderTranscript(transcript)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMError.emptyResult
        }

        let summary: String
        if text.count <= mapChunkChars {
            summary = try await client.complete(system: SummaryPrompt.finalSystem,
                                                user: text,
                                                maxTokens: maxOutputTokens)
        } else {
            let partials = try await mapPhase(text: text, client: client)
            let merged = try await reducePhase(partials: partials, client: client)
            summary = try await client.complete(system: SummaryPrompt.finalSystem,
                                                user: merged,
                                                maxTokens: maxOutputTokens)
        }

        try SummaryIO.save(summary, folder: folder)
        return summary
    }

    // MARK: - Map / Reduce

    private static func mapPhase(text: String, client: LLMClient) async throws -> [String] {
        let chunks = split(text, maxChars: mapChunkChars)
        var partials: [String] = []
        for chunk in chunks {
            let part = try await client.complete(system: SummaryPrompt.mapSystem,
                                                 user: chunk,
                                                 maxTokens: maxOutputTokens)
            partials.append(part)
        }
        return partials
    }

    private static func reducePhase(partials: [String], client: LLMClient) async throws -> String {
        var current = partials
        while current.count > 1 {
            var next: [String] = []
            var batch = ""
            for partial in current {
                if !batch.isEmpty, batch.count + partial.count > mapChunkChars {
                    next.append(try await client.complete(system: SummaryPrompt.reduceSystem,
                                                          user: batch,
                                                          maxTokens: maxOutputTokens))
                    batch = ""
                }
                batch += (batch.isEmpty ? "" : "\n\n") + partial
            }
            if !batch.isEmpty {
                next.append(try await client.complete(system: SummaryPrompt.reduceSystem,
                                                      user: batch,
                                                      maxTokens: maxOutputTokens))
            }
            // Yakınsama güvenliği: ilerleme yoksa dur.
            current = next.count < current.count ? next : [next.joined(separator: "\n\n")]
        }
        return current.first ?? ""
    }

    // MARK: - Helpers

    /// Segmentleri zaman damgalı tek metin haline getirir.
    static func renderTranscript(_ transcript: Transcript) -> String {
        transcript.segments.map { segment in
            "[\(timestamp(segment.start))] \(segment.text)"
        }.joined(separator: "\n")
    }

    /// Metni yaklaşık `maxChars` uzunluğunda, satır sınırlarında parçalara böler.
    static func split(_ text: String, maxChars: Int) -> [String] {
        guard text.count > maxChars else { return [text] }
        var chunks: [String] = []
        var current = ""
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let lineString = String(line)
            if !current.isEmpty, current.count + lineString.count + 1 > maxChars {
                chunks.append(current)
                current = ""
            }
            current += (current.isEmpty ? "" : "\n") + lineString
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    private static func timestamp(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
