import Foundation

/// Hangi ses kaynaklarının kaydedileceği.
enum CaptureSource: String, CaseIterable, Identifiable {
    case application
    case microphone
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .application: return "Uygulama sesi"
        case .microphone: return "Mikrofon"
        case .both: return "Uygulama + Mikrofon"
        }
    }
}

/// Seçilen kaynak(lar)ı birlikte başlatıp durdurur; toplantı klasörünü oluşturur.
@MainActor
final class CaptureCoordinator {
    private let appCapture = ProcessTapCapture()
    private let micCapture = MicrophoneCapture()

    private(set) var isRecording = false
    private(set) var currentFolder: URL?

    @discardableResult
    func start(source: CaptureSource, process: AudioProcess?, basePath: String) throws -> URL {
        if source != .microphone, process == nil {
            throw CaptureError.noApplicationSelected
        }
        let folder = try MeetingFolder.create(at: basePath)
        currentFolder = folder

        if source != .microphone, let process {
            try appCapture.start(process: process, to: folder.appendingPathComponent("app.caf"))
        }
        if source != .application {
            try micCapture.start(to: folder.appendingPathComponent("mic.caf"))
        }
        isRecording = true
        return folder
    }

    func stop() {
        appCapture.stop()
        micCapture.stop()
        isRecording = false
    }
}
