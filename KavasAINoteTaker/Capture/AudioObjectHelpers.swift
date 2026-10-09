import CoreAudio
import Foundation

/// Core Audio property erişimi için küçük yardımcılar.
enum AudioObject {
    static let system = AudioObjectID(kAudioObjectSystemObject)
}

func caAddress(_ selector: AudioObjectPropertySelector,
               scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal)
    -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector,
                               mScope: scope,
                               mElement: kAudioObjectPropertyElementMain)
}

extension AudioObjectID {
    var isValid: Bool { self != AudioObjectID(kAudioObjectUnknown) }

    func propertyDataSize(_ selector: AudioObjectPropertySelector,
                          scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> UInt32 {
        var addr = caAddress(selector, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(self, &addr, 0, nil, &size) == noErr else { return 0 }
        return size
    }

    func uint32(_ selector: AudioObjectPropertySelector) -> UInt32? {
        var addr = caAddress(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(self, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    func pid(_ selector: AudioObjectPropertySelector) -> pid_t? {
        var addr = caAddress(selector)
        var value: pid_t = 0
        var size = UInt32(MemoryLayout<pid_t>.size)
        guard AudioObjectGetPropertyData(self, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    func string(_ selector: AudioObjectPropertySelector) -> String? {
        var addr = caAddress(selector)
        var value: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        guard AudioObjectGetPropertyData(self, &addr, 0, nil, &size, &value) == noErr,
              let value else { return nil }
        return value as String
    }

    func arrayOfIDs(_ selector: AudioObjectPropertySelector) -> [AudioObjectID] {
        var addr = caAddress(selector)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(self, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(self, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    func streamDescription(_ selector: AudioObjectPropertySelector) -> AudioStreamBasicDescription? {
        var addr = caAddress(selector)
        var asbd = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        guard AudioObjectGetPropertyData(self, &addr, 0, nil, &size, &asbd) == noErr else { return nil }
        return asbd
    }
}
