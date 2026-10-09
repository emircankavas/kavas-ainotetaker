import Foundation

/// ASR çıktısındaki tekrar/halüsinasyon temizliği.
/// Qwen3-ASR gibi modeller (özellikle sessizlik/uzun parçalarda) devasa döngülere girebiliyor
/// (ör. bir ilk chunk 100.000+ karakter döndürdü). Bu, kullanıcıya "aynı cümle tekrar tekrar" görünür.
enum TranscriptCleaner {
    static func clean(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // 1) Metnin tamamı periyodikse tek birime indir.
        text = collapseWholeRepeats(text)

        // 2) Cümle dizisi üzerinde döngü bloklarını (A B C A B C A B C…) temizle.
        var sentences = splitSentences(text)
        if sentences.count > 1 {
            sentences = collapseLoops(sentences)
            sentences = dedupeAdjacent(sentences)
            text = sentences.joined(separator: " ")
        }

        // 3) Arka arkaya aynı kelime tekrarlarını sadeleştir.
        text = collapseDuplicateWords(text)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Cümle ayrıştırma

    private static func splitSentences(_ text: String) -> [String] {
        let pattern = "[^.!?\\n]+[.!?]?"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [text] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Cümle dizisindeki periyodik döngüleri tek bir periyoda indirir.
    /// "A B C A B C A B C" → "A B C";  "A A A A" → "A".
    private static func collapseLoops(_ sentences: [String]) -> [String] {
        let keys = sentences.map { $0.lowercased() }
        let n = keys.count
        var result: [String] = []
        var i = 0
        let maxPeriod = 40
        while i < n {
            var collapsed = false
            let maxQ = min(maxPeriod, (n - i) / 2)
            if maxQ >= 1 {
                for q in 1...maxQ {
                    var reps = 1
                    while i + (reps + 1) * q <= n {
                        var equal = true
                        for k in 0..<q where keys[i + k] != keys[i + reps * q + k] {
                            equal = false
                            break
                        }
                        if !equal { break }
                        reps += 1
                    }
                    // Uzun blok 2+ kez, kısa blok 3+ kez tekrarlanınca döngü say.
                    let threshold = q >= 2 ? 2 : 3
                    if reps >= threshold {
                        for k in 0..<q { result.append(sentences[i + k]) }
                        i += reps * q
                        collapsed = true
                        break
                    }
                }
            }
            if !collapsed {
                result.append(sentences[i])
                i += 1
            }
        }
        return result
    }

    /// Arka arkaya aynı cümleleri tek tekrara indirir.
    private static func dedupeAdjacent(_ sentences: [String]) -> [String] {
        var result: [String] = []
        var previous = ""
        for sentence in sentences {
            let key = sentence.lowercased()
            if key == previous { continue }
            result.append(sentence)
            previous = key
        }
        return result
    }

    // MARK: - Metin seviyesi

    /// Tüm metin, aynı birimin (yarım kalabilen) arka arkaya tekrarıysa bir kez bırakır.
    private static func collapseWholeRepeats(_ text: String) -> String {
        let chars = Array(text)
        let n = chars.count
        guard n >= 6, n <= 300_000 else { return text }
        for p in 1...(n / 2) {
            var periodic = true
            var i = p
            while i < n {
                if chars[i] != chars[i - p] { periodic = false; break }
                i += 1
            }
            guard periodic else { continue }
            let repeats = n / p
            let unit = String(chars[0..<p]).trimmingCharacters(in: .whitespaces)
            if (p >= 8 && repeats >= 2) || (p >= 3 && repeats >= 4) {
                return unit
            }
        }
        return text
    }

    /// Arka arkaya aynı kelimenin 3+ kez tekrarını 1'e indirir.
    private static func collapseDuplicateWords(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\b(\\S+)(\\s+\\1\\b){2,}",
                                                    options: [.caseInsensitive]) else { return text }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "$1")
    }
}
