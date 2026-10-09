import AppKit
import CoreAudio
import Foundation

/// Ses çıkışı yapan, çalışan bir uygulama süreci (Core Audio process object).
struct AudioProcess: Identifiable, Hashable {
    let objectID: AudioObjectID
    let pid: pid_t
    let bundleID: String?
    let name: String

    var id: AudioObjectID { objectID }
}

/// Çalışan ve ses çıkışı olan uygulamaları listeler (kayıt için seçim kaynağı).
enum AudioProcessList {
    static func running() -> [AudioProcess] {
        let ids = AudioObject.system.arrayOfIDs(kAudioHardwarePropertyProcessObjectList)
        let processes: [AudioProcess] = ids.compactMap { id in
            guard let pid = id.pid(kAudioProcessPropertyPID) else { return nil }
            let isOutput = (id.uint32(kAudioProcessPropertyIsRunningOutput) ?? 0) != 0
            guard isOutput else { return nil } // yalnızca ses çıkışı olanlar
            let bundleID = id.string(kAudioProcessPropertyBundleID)
            let name = NSRunningApplication(processIdentifier: pid)?.localizedName
                ?? bundleID
                ?? "PID \(pid)"
            return AudioProcess(objectID: id, pid: pid, bundleID: bundleID, name: name)
        }
        return processes.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
