import Foundation

/// Bir GitHub release'inden gelen güncelleme bilgisi.
struct UpdateInfo: Sendable {
    let currentVersion: String
    let latestVersion: String
    let name: String
    let notes: String
    let htmlURL: String
    let publishedAt: String
    let assetName: String?
    let assetURL: String?
    let prerelease: Bool

    var isNewer: Bool { UpdateChecker.isVersion(latestVersion, newerThan: currentVersion) }
}

/// GitHub Releases API'sinden en son sürümü çeker ve mevcut sürümle karşılaştırır.
enum UpdateChecker {
    static let owner = "emircankavas"
    static let repo = "kavas-ainotetaker"

    static var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    static func check() async throws -> UpdateInfo? {
        // Önbellek-bozucu parametre: aynı sürümü eski yanıttan okumayalım.
        let stamp = Int(Date().timeIntervalSince1970)
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest?t=\(stamp)") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("KavasAINoteTaker", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await HTTP.session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            AppLog.info("Güncelleme kontrolü: yanıt alınamadı")
            return nil
        }

        let tag = (obj["tag_name"] as? String) ?? ""
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let assets = obj["assets"] as? [[String: Any]] ?? []
        let zipAsset = assets.first { ($0["name"] as? String)?.hasSuffix(".zip") == true }

        let info = UpdateInfo(currentVersion: currentVersion,
                              latestVersion: version,
                              name: (obj["name"] as? String) ?? "Sürüm \(version)",
                              notes: (obj["body"] as? String) ?? "",
                              htmlURL: (obj["html_url"] as? String) ?? "",
                              publishedAt: (obj["published_at"] as? String) ?? "",
                              assetName: zipAsset?["name"] as? String,
                              assetURL: zipAsset?["browser_download_url"] as? String,
                              prerelease: (obj["prerelease"] as? Bool) ?? false)
        AppLog.info("Güncelleme kontrolü: mevcut=\(currentVersion) en son=\(version) yeniVar=\(info.isNewer)")
        return info
    }

    /// Basit semver karşılaştırması: "0.1.10" > "0.1.9".
    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
