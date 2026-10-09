import Foundation
import Observation

/// Uygulamanın çalışma-zamanı durumu.
@Observable
@MainActor
final class AppState {
    enum Phase: String {
        case idle = "Hazır"
        case recording = "Kaydediliyor…"
        case transcribing = "Transkript çıkarılıyor…"
        case summarizing = "Özetleniyor…"
        case done = "Tamamlandı"
        case failed = "Hata"
    }

    var phase: Phase = .idle
    var statusText: String = "Ayarlardan endpoint ve API anahtarlarını girin, sonra bir uygulama seçin."
    var lastError: String?
    var progress: Double?

    // Kayıt durumu
    var availableProcesses: [AudioProcess] = []
    var selectedProcess: AudioProcess?
    var captureSource: CaptureSource = .both
    private(set) var lastFolder: URL?
    private(set) var lastTranscript: Transcript?
    var lastSummaryPreview: String?

    // Toplantı listesi
    var meetings: [Meeting] = []
    var selectedMeeting: Meeting?

    private let coordinator = CaptureCoordinator()

    var isBusy: Bool {
        phase == .recording || phase == .transcribing || phase == .summarizing
    }

    var canTranscribe: Bool { lastFolder != nil && !isBusy }
    var canSummarize: Bool { lastTranscript != nil && !isBusy }

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
            statusText = "Kaydediliyor → \(folder.lastPathComponent)"
        } catch {
            phase = .failed
            lastError = error.localizedDescription
            statusText = "Kayıt başlatılamadı."
        }
    }

    func stopRecording() {
        coordinator.stop()
        phase = .idle
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
            } catch {
                phase = .failed
                lastError = error.localizedDescription
                statusText = "Transkript çıkarılamadı."
            }
        }
    }

    // MARK: - Summarize

    func summarizeLast() {
        guard let folder = lastFolder, let transcript = lastTranscript, !isBusy else { return }
        phase = .summarizing
        lastError = nil
        statusText = "Toplantı özeti çıkarılıyor… (LLM)"

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
            } catch {
                phase = .failed
                lastError = error.localizedDescription
                statusText = "Özet çıkarılamadı."
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
        } else if !meeting.hasSummary {
            if let transcript = MeetingStore.loadTranscript(folder: meeting.folder) {
                lastTranscript = transcript
                summarizeLast()
            }
        }
    }
}
