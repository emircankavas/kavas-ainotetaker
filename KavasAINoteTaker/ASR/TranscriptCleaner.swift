import Foundation

/// ASR çıktısındaki tekrar/halüsinasyon temizliği.
/// Qwen3-ASR gibi modeller (özellikle sessizlik veya çok kısa parçalarda) aynı cümleyi/kelimeyi
/// döngüye sokabiliyor; bu, kullanıcıya "aynı cümle onlarca kez" olarak görünür.
enum TranscriptCleaner {
    /// Ham ASR metnini temizler: tekrar eden cümleleri, kelime döngülerini ve boşlukları sadeleştirir.
    static func clean(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        // Boşlukları normalize et.
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        text = collapseWholeRepeats(text)
        text = collapseDuplicateSentences(text)
        text = collapseDuplicateWords(text)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Tüm metin, aynı birimin (yarım kalabilen) arka arkaya tekrarıysa bir kez bırakır.
    /// ör. "Merhaba dünya. Merhaba dünya. Merhaba dünya. Merhaba dünya" (son yarım) → "Merhaba dünya."
    /// Standart periyodiklik testi: chars[i] == chars[i-p] tüm i>=p için (tam bölünebilme şartı yok).
    private static func collapseWholeRepeats(_ text: String) -> String {
        let chars = Array(text)
        let n = chars.count
        guard n >= 6, n <= 60_000 else { return text }
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
            // Uzun birim (cümle) 2+ kez, kısa birim 4+ kez tekrarlanınca sadeleştir.
            if (p >= 8 && repeats >= 2) || (p >= 3 && repeats >= 4) {
                return unit
            }
        }
        return text
    }

    /// Arka arkaya aynı cümleleri tekrarlarını kaldırır.
    private static func collapseDuplicateSentences(_ text: String) -> String {
        // Cümlelere böl (noktalama ve satır sonları); ayraçları koru.
        let pattern = "([^.!?\\n]+[.!?]?)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var sentences: [String] = matches.map { ns.substring(with: $0.range).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard sentences.count > 1 else { return text }

        var result: [String] = []
        var previousKey = ""
        for sentence in sentences {
            let key = sentence.lowercased()
            if key == previousKey { continue } // arka arkaya aynı cümle → atla
            result.append(sentence)
            previousKey = key
        }
        sentences = result
        return sentences.joined(separator: " ")
    }

    /// Arka arkaya aynı kelimenin 3+ kez tekrarını 1'e indirir ("evet evet evet evet" → "evet").
    /// 2'li tekrarlar (vurgu) korunur.
    private static func collapseDuplicateWords(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\b(\\S+)(\\s+\\1\\b){2,}",
                                                    options: [.caseInsensitive]) else { return text }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "$1")
    }
}
