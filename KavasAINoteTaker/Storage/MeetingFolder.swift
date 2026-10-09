import Foundation

/// Her toplantı için zaman damgalı bir çıktı klasörü oluşturur.
enum MeetingFolder {
    static func create(at basePath: String) throws -> URL {
        let expanded = (basePath as NSString).expandingTildeInPath
        let base = URL(fileURLWithPath: expanded, isDirectory: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let folder = base.appendingPathComponent(formatter.string(from: Date()), isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
