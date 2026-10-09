import AVFoundation
import CoreAudio
import Foundation

/// Core Audio process tap ile SEÇİLİ bir uygulamanın sesini yakalar (macOS 14.2+).
///
/// Akış: PID → process object → CATapDescription → AudioHardwareCreateProcessTap →
/// yalnızca tap içeren private aggregate device → IO proc ile PCM yazımı.
final class ProcessTapCapture {
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private var file: AVAudioFile?
    private var format: AVAudioFormat?
    private let queue = DispatchQueue(label: "com.emircankavas.KavasAINoteTaker.tap-io")
    private(set) var isRecording = false

    func start(process: AudioProcess, to url: URL) throws {
        guard !isRecording else { return }

        try createTap(for: process.objectID)
        try createAggregate()

        guard var asbd = tapID.streamDescription(kAudioTapPropertyFormat) else {
            throw CaptureError.tapFormatUnavailable
        }
        guard let fmt = AVAudioFormat(streamDescription: &asbd) else {
            throw CaptureError.formatConversion
        }
        format = fmt

        let settings: [String: Any] = [
            AVFormatIDKey: asbd.mFormatID,
            AVSampleRateKey: fmt.sampleRate,
            AVNumberOfChannelsKey: fmt.channelCount,
        ]
        file = try AVAudioFile(forWriting: url,
                               settings: settings,
                               commonFormat: .pcmFormatFloat32,
                               interleaved: fmt.isInterleaved)

        var newProcID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&newProcID, aggregateID, queue) { [weak self] _, inInputData, _, _, _ in
            guard let self, let file = self.file, let format = self.format else { return }
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                                bufferListNoCopy: inInputData,
                                                deallocator: nil) else { return }
            try? file.write(from: buffer)
        }
        guard status == noErr, let createdProc = newProcID else {
            throw CaptureError.ioProc(status)
        }
        procID = createdProc

        let startStatus = AudioDeviceStart(aggregateID, createdProc)
        guard startStatus == noErr else {
            AudioDeviceDestroyIOProcID(aggregateID, createdProc)
            procID = nil
            throw CaptureError.deviceStart(startStatus)
        }
        isRecording = true
    }

    func stop() {
        guard isRecording else { return }
        if aggregateID.isValid, let procID {
            AudioDeviceStop(aggregateID, procID)
            AudioDeviceDestroyIOProcID(aggregateID, procID)
        }
        procID = nil
        file = nil
        format = nil
        if aggregateID.isValid {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID.isValid {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        isRecording = false
    }

    // MARK: - Private

    private func createTap(for objectID: AudioObjectID) throws {
        let description = CATapDescription(stereoMixdownOfProcesses: [objectID])
        description.uuid = UUID()
        description.muteBehavior = .unmuted
        var newTapID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateProcessTap(description, &newTapID)
        guard status == noErr else { throw CaptureError.tapCreation(status) }
        tapID = newTapID
    }

    private func createAggregate() throws {
        guard let tapUID = tapID.string(kAudioTapPropertyUID) else {
            throw CaptureError.tapUIDUnavailable
        }
        // Tap-only private aggregate: fiziksel çıkış subdevice'ı EKLENMEZ,
        // böylece çıkış cihazı değişince (kulaklık/AirPods) tap kendi hızında akmaya devam eder.
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "KavasAINoteTaker-Tap",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapDriftCompensationKey: true,
                    kAudioSubTapUIDKey: tapUID,
                ]
            ],
        ]
        var newAggregateID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &newAggregateID)
        guard status == noErr else { throw CaptureError.aggregateCreation(status) }
        aggregateID = newAggregateID
    }
}
