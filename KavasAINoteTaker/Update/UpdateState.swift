import Foundation
import Observation

/// Güncelleme kontrolünün uygulama geneli durumu (rozet için).
@Observable
@MainActor
final class UpdateState {
    private(set) var available: UpdateInfo?

    func checkOnLaunch() {
        guard SettingsStore.checkUpdatesOnLaunch else { return }
        Task {
            let result = try? await UpdateChecker.check()
            // Yalnızca GERÇEKTEN daha yeni bir sürüm varsa rozeti göster.
            available = (result?.isNewer == true) ? result : nil
            if let info = available {
                AppLog.info("Yeni sürüm mevcut: \(info.latestVersion)")
            }
        }
    }
}
