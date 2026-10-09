import Foundation

/// Toplantı klasörlerini listeler, meta okur/yazar, çıktıları yükler.
enum MeetingStore {
    static func list(basePath: String) -> [Meeting] {
        let expanded = (basePath as NSString).expandingTildeInPath
        let base = URL(fileURLWithPath: expanded, isDirectory: true)
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: base,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey],
            options: [.skipsHiddenFiles]) else {
            return []
        }

        var meetings: [Meeting] = []
        for entry in entries {
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDir else { continue }

            let meta = readMeta(folder: entry)
            let created = meta?.createdAt
                ?? (try? entry.resourceValues(forKeys: [.creationDateKey]))?.creationDate
                ?? Date.distantPast
            meetings.append(Meeting(
                folder: entry,
                name: meta?.name ?? entry.lastPathComponent,
                createdAt: created,
                appName: meta?.appName,
                hasTranscript: fm.fileExists(atPath: entry.appendingPathComponent("transcript.json").path),
                hasSummary: fm.fileExists(atPath: entry.appendingPathComponent("summary.md").path)))
        }
        return meetings.sorted { $0.createdAt > $1.createdAt }
    }

    static func readMeta(folder: URL) -> MeetingMeta? {
        let url = folder.appendingPathComponent("meta.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MeetingMeta.self, from: data)
    }

    static func writeMeta(_ meta: MeetingMeta, folder: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(meta) else { return }
        try? data.write(to: folder.appendingPathComponent("meta.json"))
    }

    static func loadTranscript(folder: URL) -> Transcript? {
        let url = folder.appendingPathComponent("transcript.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Transcript.self, from: data)
    }

    static func loadSummary(folder: URL) -> String? {
        let url = folder.appendingPathComponent("summary.md")
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Bir klasördeki meta.json'ı verilen alanlarla günceller (yoksa oluşturur).
    static func updateMeta(folder: URL, update: (inout MeetingMeta) -> Void) {
        var meta = readMeta(folder: folder) ?? MeetingMeta(name: folder.lastPathComponent,
                                                           createdAt: Date())
        update(&meta)
        writeMeta(meta, folder: folder)
    }
}
