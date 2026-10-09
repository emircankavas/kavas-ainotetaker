import SwiftUI

/// Ayarlar anahtarları (secret olmayanlar UserDefaults/@AppStorage'da).
enum SettingsKey {
    static let asrBaseURL = "asr.baseURL"
    static let asrModel = "asr.model"
    static let llmBaseURL = "llm.baseURL"
    static let llmModel = "llm.model"
    static let language = "asr.language"
    static let recordingsPath = "recordings.path"
    static let chunkSeconds = "asr.chunkSeconds"
    static let maxConcurrent = "asr.maxConcurrent"
}

/// Ayarlar ekranı: endpoint + model + API anahtarları buradan düzenlenir.
/// Model adları serbest metin — aynı sağlayıcının farklı bir modeli de yazılabilir.
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    // ASR
    @AppStorage(SettingsKey.asrBaseURL) private var asrBaseURL = "https://api.example.com/v1"
    @AppStorage(SettingsKey.asrModel) private var asrModel = "qwen3-asr"
    @State private var asrAPIKey = Keychain.get(KeychainKey.asrAPIKey) ?? ""

    // LLM
    @AppStorage(SettingsKey.llmBaseURL) private var llmBaseURL = "https://api.example.com/v1"
    @AppStorage(SettingsKey.llmModel) private var llmModel = "deepseek-v4.1-flash"
    @State private var llmAPIKey = Keychain.get(KeychainKey.llmAPIKey) ?? ""

    // Genel
    @AppStorage(SettingsKey.language) private var language = "auto"
    @AppStorage(SettingsKey.recordingsPath) private var recordingsPath = defaultRecordingsPath
    @AppStorage(SettingsKey.chunkSeconds) private var chunkSeconds = 120.0
    @AppStorage(SettingsKey.maxConcurrent) private var maxConcurrent = 4

    var body: some View {
        Form {
            Section("ASR — Transkript (Qwen3-ASR)") {
                TextField("Endpoint (base_url)", text: $asrBaseURL, prompt: Text("https://host/v1"))
                TextField("Model", text: $asrModel, prompt: Text("qwen3-asr"))
                SecureField("API anahtarı", text: $asrAPIKey)
                    .onChange(of: asrAPIKey) { _, newValue in
                        Keychain.set(newValue, for: KeychainKey.asrAPIKey)
                    }
                Text("Aynı sağlayıcının farklı bir modelini de yazabilirsiniz (ör. Qwen/Qwen3-ASR-1.7B).")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Özet — LLM") {
                TextField("Endpoint (base_url)", text: $llmBaseURL, prompt: Text("https://host/v1"))
                TextField("Model", text: $llmModel, prompt: Text("deepseek-v4.1-flash"))
                SecureField("API anahtarı", text: $llmAPIKey)
                    .onChange(of: llmAPIKey) { _, newValue in
                        Keychain.set(newValue, for: KeychainKey.llmAPIKey)
                    }
            }

            Section("Kayıt") {
                Picker("Dil", selection: $language) {
                    Text("Otomatik").tag("auto")
                    Text("Türkçe").tag("tr")
                    Text("İngilizce").tag("en")
                }
                TextField("Kayıt klasörü", text: $recordingsPath)
                TextField("ASR parça süresi (sn)", value: $chunkSeconds, format: .number)
                Stepper("Eşzamanlı ASR isteği: \(maxConcurrent)", value: $maxConcurrent, in: 1...16)
            }

            Section {
                Label("API anahtarları macOS Keychain'de saklanır.", systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

let defaultRecordingsPath: String = {
    let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSHomeDirectory())
    return base.appendingPathComponent("KavasAINoteTaker/meetings").path
}()
