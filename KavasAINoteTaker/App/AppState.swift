import Foundation
import Observation

/// Uygulamanın çalışma-zamanı durumu.
@Observable
@MainActor
final class AppState {
    /// Kenar çubuğu bölümleri.
    enum Section: String, CaseIterable, Identifiable {
        case home, meetings, settings, about
        var id: String { rawValue }
        var title: String {
            switch self {
            case .home: return "Ana Sayfa"
            case .meetings: return "Toplantılar"
            case .settings: return "Ayarlar"
            case .about: return "Hakkında"
            }
        }
        var icon: String {
            switch self {
            case .home: return "house"
            case .meetings: return "doc.text"
            case .settings: return "gearshape"
            case .about: return "info.circle"
            }
        }
        var iconFilled: String {
            switch self {
            case .home: return "house.fill"
            case .meetings: return "doc.text.fill"
            case .settings: return "gearshape.fill"
            case .about: return "info.circle.fill"
            }
        }
    }

    enum Phase: String {
        case idle = "Hazır"
        case recording = "Kaydediliyor…"
        case transcribing = "Transkript çıkarılıyor…"
        case summarizing = "Özetleniyor…"
        case done = "Tamamlandı"
        case failed = "Hata"
    }

    var section: Section = .home
    var phase: Phase = .idle
    var statusText: String = "Kaydı başlatmak için mikrofon düğmesine basın."
    var lastError: String?
    var progress: Double?

    // Kayıt durumu
    var availableProcesses: [AudioProcess] = []
    var selectedProcess: AudioProcess?
    var captureSource: CaptureSource = .both
    var recordingElapsed: Int = 0
    private(set) var lastFolder: URL?
    private(set) var lastTranscript: Transcript?
    var lastSummaryPreview: String?
    let live = LiveTranscriber()

    // Toplantı listesi
    var meetings: [Meeting] = []
    var selectedMeeting: Meeting?

    private let coordinator = CaptureCoordinator()
    private var timerTask: Task<Void, Never>?
    private var autoChainSummary = false

    var isBusy: Bool {
        phase == .recording || phase == .transcribing || phase == .summarizing
    }
    var isRecording: Bool { phase == .recording }
    var canTranscribe: Bool { lastFolder != nil && !isBusy }
    var canSummarize: Bool { lastTranscript != nil && !isBusy }

    var elapsedText: String {
        let total = recordingElapsed
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    // MARK: - Processes

    func refreshProcesses() {
        availableProcesses = AudioProcessList.running()
        if let selected = selectedProcess, availableProcesses.contains(selected) { return }
        selectedProcess = availableProcesses.first
    }

    // MARK: - Meetings

    func refreshMeetings() {
        meetings = MeetingStore.list(basePath: SettingsStore.recordingsPath)
    }

    // MARK: - Record

    func startRecording(recordingsPath: String) {
        do {
            let folder = try coordinator.start(source: captureSource,
                                                process: selectedProcess,
                                                basePath: recordingsPath)
            lastFolder = folder
            lastTranscript = nil
            lastSummaryPreview = nil
            MeetingStore.updateMeta(folder: folder) { meta in
                meta.appName = selectedProcess?.name
                meta.source = captureSource.label
            }
            phase = .recording
            lastError = nil
            section = .home
            statusText = "Kaydediliyor → \(folder.lastPathComponent)"
            AppLog.info("Kayıt başladı: \(folder.lastPathComponent) | kaynak=\(captureSource.label) | uygulama=\(selectedProcess?.name ?? "-")")
            startTimer()

            if SettingsStore.liveTranscription, !SettingsStore.asrBaseURL.isEmpty {
                let client = OpenAICompatASRClient(baseURL: SettingsStore.asrBaseURL,
                                                   apiKey: SettingsStore.asrAPIKey,
                                                   model: SettingsStore.asrModel)
                live.start(folder: folder, client: client, language: SettingsStore.language)
            } else if !SettingsStore.liveTranscription {
                live.setDisabled("kapalı (Ayarlar → Genel → Canlı transkript)")
            } else {
                live.setDisabled("ASR endpoint ayarlı değil")
            }
        } catch {
            phase = .failed
            lastError = error.localizedDescription
            statusText = "Kayıt başlatılamadı."
            AppLog.error(error, "Kayıt başlatılamadı")
        }
    }

    func stopRecording() {
        coordinator.stop()
        live.stop()
        live.clear()
        stopTimer()
        AppLog.info("Kayıt durdu: \(recordingElapsed) sn")
        phase = .idle

        // Kayıt durunca: tam sesle transkript (+ özet) otomatik üret (ilk saniyeler dahil, kalıcı).
        if SettingsStore.autoProcessOnStop, lastFolder != nil {
            refreshMeetings()
            autoChainSummary = true
            transcribeLast()
            return
        }
        refreshMeetings()
        statusText = "Kayıt durduruldu. Transkript çıkarmak için \"Transkript Çıkar\" düğmesine basın."
    }

    // MARK: - Transcribe

    func transcribeLast() {
        guard let folder = lastFolder, !isBusy else { return }
        phase = .transcribing
        lastError = nil
        progress = nil
        statusText = "Transkript çıkarılıyor… (miks + parçalama + ASR)"
        AppLog.info("Transkript başladı: \(folder.lastPathComponent) | model=\(SettingsStore.asrModel)")

        let baseURL = SettingsStore.asrBaseURL
        let apiKey = SettingsStore.asrAPIKey
        let model = SettingsStore.asrModel
        let language = SettingsStore.language
        let chunkSeconds = SettingsStore.chunkSeconds
        let maxConcurrent = SettingsStore.maxConcurrent

        Task {
            do {
                let transcript = try await Task.detached(priority: .userInitiated) {
                    let client = OpenAICompatASRClient(baseURL: baseURL, apiKey: apiKey, model: model)
                    return try await TranscriptionPipeline.run(folder: folder,
                                                               client: client,
                                                               language: language,
                                                               chunkSeconds: chunkSeconds,
                                                               maxConcurrent: maxConcurrent)
                }.value
                lastTranscript = transcript
                MeetingStore.updateMeta(folder: folder) { $0.asrModel = model }
                phase = .done
                refreshMeetings()
                statusText = "Transkript hazır: \(transcript.segments.count) parça → transcript.txt"
                AppLog.info("Transkript OK: \(transcript.segments.count) parça, \(transcript.fullText.count) karakter")
                if autoChainSummary {
                    autoChainSummary = false
                    summarizeLast()
                }
            } catch {
                phase = .failed
                lastError = error.localizedDescription
                statusText = "Transkript çıkarılamadı."
                AppLog.error(error, "Transkript başarısız")
            }
        }
    }

    // MARK: - Summarize

    func summarizeLast() {
        guard let folder = lastFolder, let transcript = lastTranscript, !isBusy else { return }
        phase = .summarizing
        lastError = nil
        statusText = "Toplantı özeti çıkarılıyor… (LLM)"
        AppLog.info("Özet başladı: \(folder.lastPathComponent) | model=\(SettingsStore.llmModel)")

        let baseURL = SettingsStore.llmBaseURL
        let apiKey = SettingsStore.llmAPIKey
        let model = SettingsStore.llmModel

        Task {
            do {
                let summary = try await Task.detached(priority: .userInitiated) {
                    let client = OpenAICompatLLMClient(baseURL: baseURL, apiKey: apiKey, model: model)
                    return try await Summarizer.run(folder: folder, transcript: transcript, client: client)
                }.value
                MeetingStore.updateMeta(folder: folder) { $0.llmModel = model }
                phase = .done
                lastSummaryPreview = summary
                refreshMeetings()
                statusText = "Özet hazır → summary.md"
                AppLog.info("Özet OK: \(summary.count) karakter")
            } catch {
                phase = .failed
                lastError = error.localizedDescription
                statusText = "Özet çıkarılamadı."
                AppLog.error(error, "Özet başarısız")
            }
        }
    }

    // MARK: - List actions

    func selectMeeting(_ meeting: Meeting) {
        selectedMeeting = meeting
    }

    /// Seçili toplantı için eksik olanı sırayla üretir: transkript yoksa transkript, sonra özet.
    func processSelectedMeeting() {
        guard let meeting = selectedMeeting, !isBusy else { return }
        lastFolder = meeting.folder
        if !meeting.hasTranscript {
            transcribeLast()
        } else if !meeting.hasSummary,
                  let transcript = MeetingStore.loadTranscript(folder: meeting.folder) {
            lastTranscript = transcript
            summarizeLast()
        }
    }

    // MARK: - Import (ses/video)

    /// Bir ses/video dosyasını içe aktarır: sesi ayıklar → transkript → özet.
    func importFile(_ url: URL) {
        guard !isBusy else { return }
        let fm = FileManager.default
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            // Dosyayı çalışma alanına kopyala (güvenlik-kapsamlı erişim sonrası kalıcı olsun).
            let folder = try MeetingFolder.create(at: SettingsStore.recordingsPath)
            let ext = url.pathExtension.isEmpty ? "dat" : url.pathExtension
            let stored = folder.appendingPathComponent("imported.\(ext)")
            try? fm.removeItem(at: stored)
            try fm.copyItem(at: url, to: stored)
            lastFolder = folder
            lastTranscript = nil
            lastSummaryPreview = nil
            MeetingStore.updateMeta(folder: folder) { meta in
                meta.name = url.deletingPathExtension().lastPathComponent
                meta.source = "İçe aktarıldı"
                meta.appName = ext.uppercased()
            }
            section = .meetings
            phase = .transcribing
            lastError = nil
            statusText = "İçe aktarılıyor: \(url.lastPathComponent) — ses ayıklanıyor…"
            AppLog.info("İçe aktarma: \(url.lastPathComponent) (\(ext))")

            let baseURL = SettingsStore.asrBaseURL
            let apiKey = SettingsStore.asrAPIKey
            let model = SettingsStore.asrModel
            let language = SettingsStore.language
            let chunkSeconds = SettingsStore.chunkSeconds
            let maxConcurrent = SettingsStore.maxConcurrent

            Task {
                do {
                    let transcript = try await Task.detached(priority: .userInitiated) {
                        let client = OpenAICompatASRClient(baseURL: baseURL, apiKey: apiKey, model: model)
                        return try await TranscriptionPipeline.runImport(source: stored,
                                                                         folder: folder,
                                                                         client: client,
                                                                         language: language,
                                                                         chunkSeconds: chunkSeconds,
                                                                         maxConcurrent: maxConcurrent)
                    }.value
                    lastTranscript = transcript
                    MeetingStore.updateMeta(folder: folder) { $0.asrModel = model }
                    refreshMeetings()
                    if let updated = meetings.first(where: { $0.folder == folder }) {
                        selectedMeeting = updated
                    }
                    phase = .done
                    statusText = "İçe aktarma tamam: \(transcript.segments.count) parça. Özet çıkarabilirsiniz."
                    AppLog.info("İçe aktarma OK: \(transcript.segments.count) parça")
                } catch {
                    phase = .failed
                    lastError = error.localizedDescription
                    statusText = "İçe aktarma başarısız."
                    AppLog.error(error, "İçe aktarma başarısız")
                }
            }
        } catch {
            phase = .failed
            lastError = error.localizedDescription
            statusText = "Dosya içe aktarılamadı."
            AppLog.error(error, "Dosya kopyalanamadı")
        }
    }

    // MARK: - Timer

    private func startTimer() {
        recordingElapsed = 0
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { break }
                self.recordingElapsed += 1
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
