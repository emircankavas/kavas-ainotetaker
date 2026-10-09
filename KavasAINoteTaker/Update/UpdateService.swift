import AppKit
import Foundation

/// Release asset'ini indirir, açar ve çalışan uygulamayı yenisiyle değiştirip yeniden başlatır.
enum UpdateService {
    enum UpdateError: LocalizedError {
        case noAsset
        case download
        case extract
        case notWritable(String)

        var errorDescription: String? {
            switch self {
            case .noAsset: return "Release'te indirilebilir .zip bulunamadı."
            case .download: return "Güncelleme indirilemedi."
            case .extract: return "İndirilen paket açılamadı."
            case .notWritable(let path):
                return "Uygulama konumu yazılabilir değil: \(path). Elle güncelleyin."
            }
        }
    }

    /// İndirir, açar, yerine koyar ve uygulamayı yeniden başlatır (ardından çıkış yapar).
    static func downloadAndInstall(_ info: UpdateInfo) async throws {
        guard let assetURLString = info.assetURL, let assetURL = URL(string: assetURLString) else {
            throw UpdateError.noAsset
        }
        AppLog.info("Güncelleme indiriliyor: \(info.assetName ?? assetURL.lastPathComponent)")

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("kavat-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        // 1) İndir
        let (data, response) = try await HTTP.session.data(from: assetURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw UpdateError.download
        }
        let zipURL = tmp.appendingPathComponent(info.assetName ?? "update.zip")
        try data.write(to: zipURL)

        // 2) Aç (ditto)
        let extractDir = tmp.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try run("/usr/bin/ditto", ["-x", "-k", zipURL.path, extractDir.path])

        // 3) .app'i bul
        let contents = try FileManager.default.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil)
        guard let newApp = contents.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError.extract
        }

        // 4) Eski sürümü indirilen yere yedekle
        let oldAppPath = Bundle.main.bundlePath
        let oldApp = URL(fileURLWithPath: oldAppPath)
        let oldDir = oldApp.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: oldDir.path) else {
            throw UpdateError.notWritable(oldDir.path)
        }

        // 5) Güncelleyici betiği: uygulama KAPANANA kadar bekle, sonra değiştir.
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = tmp.appendingPathComponent("apply.sh")
        let scriptBody = """
        #!/bin/bash
        # Uygulama tamamen kapanana kadar bekle.
        while kill -0 \(pid) 2>/dev/null; do sleep 0.3; done
        rm -rf "\(oldAppPath).old" 2>/dev/null
        mv "\(oldAppPath)" "\(oldAppPath).old" 2>/dev/null
        cp -R "\(newApp.path)" "\(oldAppPath)"
        xattr -dr com.apple.quarantine "\(oldAppPath)" 2>/dev/null
        rm -rf "\(oldAppPath).old" 2>/dev/null
        open "\(oldAppPath)"
        rm -rf "\(tmp.path)"
        """
        try scriptBody.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

        AppLog.info("Güncelleme uygulanıyor; uygulama kapanınca yeni sürüm başlatılacak")
        try runDetached("/bin/bash", [script.path])

        // 6) Çık (AppKit üzerinden; NSApp global'ine bağımlı değil).
        await MainActor.run {
            NSApplication.shared.terminate(nil)
        }
    }

    private static func run(_ launchPath: String, _ args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.extract }
    }

    private static func runDetached(_ launchPath: String, _ args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        try process.run()
    }
}
