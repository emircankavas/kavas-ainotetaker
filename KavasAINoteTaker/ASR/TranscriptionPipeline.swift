import Foundation

/// Kayıt klasörünü uçtan uca ASR'a çevirir: miksle → parçala → (paralel) transkript → kaydet.
enum TranscriptionPipeline {
    static func run(folder: URL,
                    client: ASRClient,
                    language: String?,
                    chunkSeconds: Double,
                    maxConcurrent: Int) async throws -> Transcript {
        let appURL = folder.appendingPathComponent("app.caf")
        let micURL = folder.appendingPathComponent("mic.caf")
        let mixedURL = folder.appendingPathComponent("mixed.wav")

        try AudioPreprocess.makeMixedWAV(appURL: appURL, micURL: micURL, outputURL: mixedURL)

        let chunksDir = folder.appendingPathComponent("chunks", isDirectory: true)
        try? FileManager.default.removeItem(at: chunksDir)
        try FileManager.default.createDirectory(at: chunksDir, withIntermediateDirectories: true)

        let chunks = try Chunking.split(wavURL: mixedURL, targetSeconds: chunkSeconds, outDir: chunksDir)
        guard !chunks.isEmpty else { throw ASRError.emptyResult }

        let segments = try await transcribeAll(chunks: chunks,
                                               client: client,
                                               language: language,
                                               maxConcurrent: max(1, maxConcurrent))
        let fullText = segments.map(\.text).joined(separator: "\n\n")
        let transcript = Transcript(segments: segments,
                                    language: (language == "auto" ? nil : language),
                                    fullText: fullText,
                                    createdAt: Date())
        try TranscriptIO.save(transcript, to: folder)
        try? FileManager.default.removeItem(at: chunksDir) // parça dosyalarını temizle
        return transcript
    }

    /// Parçaları sınırlı eşzamanlılıkla gönderir, sırayı korur.
    private static func transcribeAll(chunks: [Chunking.Chunk],
                                      client: ASRClient,
                                      language: String?,
                                      maxConcurrent: Int) async throws -> [TranscriptSegment] {
        var results = [TranscriptSegment?](repeating: nil, count: chunks.count)

        try await withThrowingTaskGroup(of: (Int, String).self) { group in
            var next = 0
            let initial = min(maxConcurrent, chunks.count)
            for i in 0..<initial {
                group.addTask { (i, try await client.transcribe(fileURL: chunks[i].url, language: language)) }
                next = initial
            }
            while let (index, text) = try await group.next() {
                results[index] = TranscriptSegment(index: index,
                                                   start: chunks[index].start,
                                                   end: chunks[index].end,
                                                   text: text)
                if next < chunks.count {
                    let j = next
                    next += 1
                    group.addTask { (j, try await client.transcribe(fileURL: chunks[j].url, language: language)) }
                }
            }
        }
        return results.compactMap { $0 }
    }
}
