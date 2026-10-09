import Foundation

/// Kayıt klasörünü (app.caf + mic.caf) veya içe aktarılan bir dosyayı uçtan uca ASR'a çevirir:
/// miks/ayıklama → VAD ile parçalama → (paralel) transkript → kaydet.
enum TranscriptionPipeline {
    /// Kayıt klasörü: app.caf + mic.caf → mixed.wav → parçala → transkript.
    static func run(folder: URL,
                    client: ASRClient,
                    language: String?,
                    chunkSeconds: Double,
                    maxConcurrent: Int) async throws -> Transcript {
        let appURL = folder.appendingPathComponent("app.caf")
        let micURL = folder.appendingPathComponent("mic.caf")
        let mixedURL = folder.appendingPathComponent("mixed.wav")
        try AudioPreprocess.makeMixedWAV(appURL: appURL, micURL: micURL, outputURL: mixedURL)
        return try await transcribe(mixedURL: mixedURL,
                                    folder: folder,
                                    client: client,
                                    language: language,
                                    chunkSeconds: chunkSeconds,
                                    maxConcurrent: maxConcurrent)
    }

    /// İçe aktarılan ses/video dosyası: sesi ayıkla → mixed.wav → parçala → transkript.
    static func runImport(source: URL,
                          folder: URL,
                          client: ASRClient,
                          language: String?,
                          chunkSeconds: Double,
                          maxConcurrent: Int) async throws -> Transcript {
        let mixedURL = folder.appendingPathComponent("mixed.wav")
        try await ImportService.extractAudio(from: source, toWAV: mixedURL)
        return try await transcribe(mixedURL: mixedURL,
                                    folder: folder,
                                    client: client,
                                    language: language,
                                    chunkSeconds: chunkSeconds,
                                    maxConcurrent: maxConcurrent)
    }

    // MARK: - Shared

    private static func transcribe(mixedURL: URL,
                                   folder: URL,
                                   client: ASRClient,
                                   language: String?,
                                   chunkSeconds: Double,
                                   maxConcurrent: Int) async throws -> Transcript {
        let chunksDir = folder.appendingPathComponent("chunks", isDirectory: true)
        try? FileManager.default.removeItem(at: chunksDir)
        try FileManager.default.createDirectory(at: chunksDir, withIntermediateDirectories: true)

        let chunks = try Chunking.split(wavURL: mixedURL, targetSeconds: chunkSeconds, outDir: chunksDir)
        guard !chunks.isEmpty else { throw ASRError.emptyResult }
        AppLog.info("Parçalama tamam: \(chunks.count) parça (hedef \(Int(chunkSeconds)) sn)")

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
        try? FileManager.default.removeItem(at: chunksDir)
        return transcript
    }

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
