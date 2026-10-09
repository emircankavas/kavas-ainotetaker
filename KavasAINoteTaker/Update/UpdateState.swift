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
            available = try? await UpdateChecker.check()
            if let info = available, info.isNewer {
                AppLog.info("Yeni sürüm mevcut: \(info.latestVersion)")
            }
        }
    }
}
