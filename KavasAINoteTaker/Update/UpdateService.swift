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
        LOG="$HOME/Library/Application Support/KavasAINoteTaker/logs/update.log"
        exec >> "$LOG" 2>&1
        echo "[$(date)] guncelleme betigi basladi, pid=\(pid) bekleniyor"
        # Uygulama tamamen kapanana kadar bekle (en fazla 30 sn).
        n=0
        while kill -0 \(pid) 2>/dev/null; do sleep 0.3; n=$((n+1)); [ $n -gt 100 ] && break; done
        echo "[$(date)] uygulama kapandi, degistiriliyor"
        rm -rf "\(oldAppPath).old"
        mv "\(oldAppPath)" "\(oldAppPath).old"
        cp -R "\(newApp.path)" "\(oldAppPath)" && echo "[$(date)] kopyalandi" || echo "[$(date)] KOPYALAMA HATASI"
        xattr -dr com.apple.quarantine "\(oldAppPath)" 2>/dev/null
        rm -rf "\(oldAppPath).old"
        open "\(oldAppPath)" && echo "[$(date)] acildi"
        rm -rf "\(tmp.path)"
        """
        try scriptBody.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

        AppLog.info("Güncelleme uygulanıyor; uygulama kapanınca yeni sürüm başlatılacak")
        try runDetached("/bin/bash", [script.path])

        // 6) Çık. terminate() bazen engellenir; garantili olması için exit(0) ile zorla.
        await MainActor.run {
            NSApplication.shared.terminate(nil)
        }
        exit(0)
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
