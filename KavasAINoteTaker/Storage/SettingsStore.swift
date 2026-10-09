import Foundation

/// Ayarlara tipli erişim (UserDefaults + Keychain). Gizli olmayan değerler
/// UserDefaults'ta, API anahtarları Keychain'de tutulur.
enum SettingsStore {
    static var asrBaseURL: String { UserDefaults.standard.string(forKey: SettingsKey.asrBaseURL) ?? "" }
    static var asrModel: String { UserDefaults.standard.string(forKey: SettingsKey.asrModel) ?? "qwen3-asr" }
    static var asrAPIKey: String { Keychain.get(KeychainKey.asrAPIKey) ?? "" }

    static var llmBaseURL: String { UserDefaults.standard.string(forKey: SettingsKey.llmBaseURL) ?? "" }
    static var llmModel: String { UserDefaults.standard.string(forKey: SettingsKey.llmModel) ?? "deepseek-v4.1-flash" }
    static var llmAPIKey: String { Keychain.get(KeychainKey.llmAPIKey) ?? "" }

    static var language: String { UserDefaults.standard.string(forKey: SettingsKey.language) ?? "auto" }
    static var recordingsPath: String {
        UserDefaults.standard.string(forKey: SettingsKey.recordingsPath) ?? defaultRecordingsPath
    }

    static var chunkSeconds: Double {
        let value = UserDefaults.standard.double(forKey: SettingsKey.chunkSeconds)
        return value > 0 ? value : 120
    }

    static var maxConcurrent: Int {
        let value = UserDefaults.standard.integer(forKey: SettingsKey.maxConcurrent)
        return value > 0 ? value : 4
    }
}
