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
    static let liveTranscription = "asr.liveTranscription"
    static let autoProcessOnStop = "app.autoProcessOnStop"
    static let checkUpdatesOnLaunch = "app.checkUpdatesOnLaunch"
}

/// Ayarlar bölümü: sekmeli kartlar (muadil meetily düzeni).
/// Model adları serbest metin — aynı sağlayıcının farklı bir modeli de yazılabilir.
struct SettingsView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case general = "Genel"
        case transcription = "Transkript"
        case summary = "Özet"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .general: return "slider.horizontal.3"
            case .transcription: return "doc.text"
            case .summary: return "sparkles"
            }
        }
    }

    @State private var tab: Tab = .general

    // ASR
    @AppStorage(SettingsKey.asrBaseURL) private var asrBaseURL = "https://api.example.com/v1"
    @AppStorage(SettingsKey.asrModel) private var asrModel = "qwen3-asr"
    @State private var asrAPIKey = Keychain.get(KeychainKey.asrAPIKey) ?? ""
    @State private var asrTest: String?

    // LLM
    @AppStorage(SettingsKey.llmBaseURL) private var llmBaseURL = "https://api.example.com/v1"
    @AppStorage(SettingsKey.llmModel) private var llmModel = "deepseek-v4.1-flash"
    @State private var llmAPIKey = Keychain.get(KeychainKey.llmAPIKey) ?? ""
    @State private var llmTest: String?

    // Kayıt
    @AppStorage(SettingsKey.language) private var language = "auto"
    @AppStorage(SettingsKey.recordingsPath) private var recordingsPath = defaultRecordingsPath
    @AppStorage(SettingsKey.chunkSeconds) private var chunkSeconds = 120.0
    @AppStorage(SettingsKey.maxConcurrent) private var maxConcurrent = 4
    @AppStorage(SettingsKey.liveTranscription) private var liveTranscription = true
    @AppStorage(SettingsKey.autoProcessOnStop) private var autoProcessOnStop = true
    @AppStorage(SettingsKey.checkUpdatesOnLaunch) private var checkUpdatesOnLaunch = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ayarlar")
                .font(.largeTitle.bold())
                .padding(.horizontal, 28)
                .padding(.top, 24)
            tabBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch tab {
                    case .general: generalTab
                    case .transcription: transcriptionTab
                    case .summary: summaryTab
                    }
                }
                .frame(maxWidth: Theme.contentMaxWidth, alignment: .leading)
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 22) {
            ForEach(Tab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                        Text(item.rawValue)
                    }
                    .font(.callout)
                    .foregroundStyle(tab == item ? Theme.accent : Color.secondary)
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(tab == item ? Theme.accent : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Tabs

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 22) {
            card(title: "Veri Depolama Konumları",
                 subtitle: "Kayıtların ve çıktıların saklandığı yer") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Toplantı Kayıtları").font(.subheadline.weight(.semibold))
                    Text(recordingsPath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Button {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: recordingsPath)
                    } label: {
                        Label("Klasörü Aç", systemImage: "folder")
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }

            card(title: "Kayıt", subtitle: "Dil ve ASR parçalama davranışı") {
                Form {
                    Picker("Dil", selection: $language) {
                        Text("Otomatik").tag("auto")
                        Text("Türkçe").tag("tr")
                        Text("İngilizce").tag("en")
                    }
                    TextField("ASR parça süresi (sn)", value: $chunkSeconds, format: .number)
                    Stepper("Eşzamanlı ASR isteği: \(maxConcurrent)", value: $maxConcurrent, in: 1...16)
                    Toggle("Canlı transkript (kayıt sırasında)", isOn: $liveTranscription)
                    Toggle("Kayıt durunca transkript + özet üret", isOn: $autoProcessOnStop)
                    Toggle("Açılışta güncellemeleri kontrol et", isOn: $checkUpdatesOnLaunch)
                }
                .formStyle(.columns)
            }
        }
    }

    private var transcriptionTab: some View {
        card(title: "Transkript (Qwen3-ASR)", subtitle: "OpenAI-uyumlu transkript uç noktası") {
            Form {
                TextField("Endpoint (base_url)", text: $asrBaseURL, prompt: Text("https://host/v1"))
                TextField("Model", text: $asrModel, prompt: Text("qwen3-asr"))
                SecureField("API anahtarı", text: $asrAPIKey)
                    .onChange(of: asrAPIKey) { _, newValue in
                        Keychain.set(newValue, for: KeychainKey.asrAPIKey)
                    }
                testRow(status: asrTest) {
                    await runTest(base: asrBaseURL, key: asrAPIKey, assign: { asrTest = $0 })
                }
            }
            .formStyle(.columns)
        }
    }

    private var summaryTab: some View {
        card(title: "Özet (LLM)", subtitle: "OpenAI-uyumlu sohbet uç noktası") {
            Form {
                TextField("Endpoint (base_url)", text: $llmBaseURL, prompt: Text("https://host/v1"))
                TextField("Model", text: $llmModel, prompt: Text("deepseek-v4.1-flash"))
                SecureField("API anahtarı", text: $llmAPIKey)
                    .onChange(of: llmAPIKey) { _, newValue in
                        Keychain.set(newValue, for: KeychainKey.llmAPIKey)
                    }
                testRow(status: llmTest) {
                    await runTest(base: llmBaseURL, key: llmAPIKey, assign: { llmTest = $0 })
                }
            }
            .formStyle(.columns)
        }
    }

    // MARK: - Building blocks

    private func card<Content: View>(title: String, subtitle: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardCorner))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardCorner).strokeBorder(.quaternary, lineWidth: 0.5))
    }

    private func testRow(status: String?, action: @escaping () async -> Void) -> some View {
        HStack {
            Button("Test Et") { Task { await action() } }
            if let status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(status.hasPrefix("Bağlantı OK") ? .green : .red)
                    .lineLimit(2)
            }
        }
    }

    private func runTest(base: String, key: String, assign: @escaping (String) -> Void) async {
        assign("Test ediliyor…")
        let result = await EndpointTester.test(baseURL: base, apiKey: key)
        assign(result.message)
    }
}

let defaultRecordingsPath: String = {
    let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSHomeDirectory())
    return base.appendingPathComponent("KavasAINoteTaker/meetings").path
}()
