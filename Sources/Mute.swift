import AppKit
import Carbon.HIToolbox
import CoreAudio

/// 🎤 Mutes the microphone itself (the default input device), so every meeting app hears silence.
/// Uses the device's own mute switch, or turns its input volume to zero (and back) if it has none.
/// Nothing is ever recorded or listened to.
enum Mic {
    private static var savedVolume: Float32?

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
    }

    private static var input: AudioObjectID? {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var dev = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev) == noErr,
              dev != 0 else { return nil }
        return dev
    }

    private static func get<T: BitwiseCopyable>(_ dev: AudioObjectID, _ selector: AudioObjectPropertySelector, _ zero: T) -> T? {
        var addr = address(selector)
        guard AudioObjectHasProperty(dev, &addr) else { return nil }
        var value = zero
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func set<T: BitwiseCopyable>(_ dev: AudioObjectID, _ selector: AudioObjectPropertySelector, _ value: T) -> Bool {
        var addr = address(selector)
        var settable: DarwinBoolean = false
        guard AudioObjectHasProperty(dev, &addr), AudioObjectIsPropertySettable(dev, &addr, &settable) == noErr,
              settable.boolValue else { return false }
        var v = value
        return AudioObjectSetPropertyData(dev, &addr, 0, nil, UInt32(MemoryLayout<T>.size), &v) == noErr
    }

    static var muted: Bool {
        guard let dev = input else { return false }
        if get(dev, kAudioDevicePropertyMute, UInt32(0)) == 1 { return true }
        return get(dev, kAudioDevicePropertyVolumeScalar, Float32(1)) == 0
    }

    /// False if the microphone can't be muted either way.
    @discardableResult static func setMuted(_ mute: Bool) -> Bool {
        guard let dev = input else { return false }
        if set(dev, kAudioDevicePropertyMute, UInt32(mute ? 1 : 0)) {
            // Undo a volume-mute from before, so unmuting really brings the mic back.
            if !mute, get(dev, kAudioDevicePropertyVolumeScalar, Float32(1)) == 0 {
                _ = set(dev, kAudioDevicePropertyVolumeScalar, savedVolume ?? 0.75)
                savedVolume = nil
            }
            return true
        }
        if mute {
            if let v = get(dev, kAudioDevicePropertyVolumeScalar, Float32(1)), v > 0 { savedVolume = v }
            return set(dev, kAudioDevicePropertyVolumeScalar, Float32(0))
        }
        defer { savedVolume = nil }
        return set(dev, kAudioDevicePropertyVolumeScalar, savedVolume ?? 0.75)
    }
}

/// A system-wide keyboard shortcut through Carbon's hot-key API, which works in every app and needs no
/// Accessibility or Input Monitoring permission.
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let id: UInt32
    private let action: () -> Void

    init?(keyCode: Int, modifiers: Int, id: UInt32, action: @escaping () -> Void) {
        self.id = id
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        guard InstallEventHandler(GetApplicationEventTarget(), { _, event, ctx in
            guard let ctx, let event else { return OSStatus(eventNotHandledErr) }
            let hk = Unmanaged<HotKey>.fromOpaque(ctx).takeUnretainedValue()
            // Every hot key of the app comes through every handler: only take our own, pass the rest on.
            var pressed = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                    MemoryLayout<EventHotKeyID>.size, nil, &pressed) == noErr,
                  pressed.signature == HotKey.signature, pressed.id == hk.id else { return OSStatus(eventNotHandledErr) }
            DispatchQueue.main.async { hk.action() }
            return noErr
        }, 1, &spec, me, &handler) == noErr else { return nil }
        let hid = EventHotKeyID(signature: Self.signature, id: id)
        guard RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hid, GetApplicationEventTarget(), 0, &ref) == noErr else {
            if let h = handler { RemoveEventHandler(h); handler = nil }   // deinit still runs
            return nil
        }
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }

    private static let signature = OSType(0x4E66_4D75)   // "NfMu"

    /// ⌃⌥M
    static func muteShortcut(_ action: @escaping () -> Void) -> HotKey? {
        HotKey(keyCode: kVK_ANSI_M, modifiers: controlKey | optionKey, id: 1, action: action)
    }

    /// ⌃⌥V
    static func clipboardShortcut(_ action: @escaping () -> Void) -> HotKey? {
        HotKey(keyCode: kVK_ANSI_V, modifiers: controlKey | optionKey, id: 2, action: action)
    }
}
