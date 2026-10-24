import AppKit
import CoreAudio
import CoreMediaIO
import IOKit.ps

/// Is anything recording from a microphone or the camera right now? Read straight from CoreAudio and
/// CoreMediaIO, so it works for every meeting app and needs no permission.
enum Devices {
    private static let system = AudioObjectID(kAudioObjectSystemObject)

    private static func address(_ selector: AudioObjectPropertySelector,
                                _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func ids(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [AudioObjectID] {
        var addr = address(selector)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var list = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &list) == noErr else { return [] }
        return list
    }

    private static func uint(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                             _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> UInt32? {
        var addr = address(selector, scope)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }

    static func name(_ device: AudioObjectID) -> String? { string(device, kAudioObjectPropertyName) }

    static var audioDevices: [AudioObjectID] { ids(system, kAudioHardwarePropertyDevices) }

    static func hasOutput(_ device: AudioObjectID) -> Bool {
        var addr = address(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &addr, 0, nil, &size) == noErr && size > 0
    }

    static func isBluetooth(_ device: AudioObjectID) -> Bool {
        let t = uint(device, kAudioDevicePropertyTransportType)
        return t == kAudioDeviceTransportTypeBluetooth || t == kAudioDeviceTransportTypeBluetoothLE
    }

    /// Always-listening voice assistants keep a mic open all day without anyone being on a call.
    /// (com.stangudu.* covers the author's own apps, some of which listen for a wake word.)
    private static func ignored(_ bundle: String) -> Bool {
        ["com.apple.corespeechd", "com.apple.assistantd", "com.apple.Siri", "com.apple.SpeechRecognitionCore",
         "com.apple.accessibility.heard", "com.stangudu."].contains { bundle.hasPrefix($0) }
    }

    /// True while some *other* app records from a microphone.
    static var micInUse: Bool {
        if #available(macOS 14.2, *) {
            let me = ProcessInfo.processInfo.processIdentifier
            return ids(system, kAudioHardwarePropertyProcessObjectList).contains { p in
                guard uint(p, kAudioProcessPropertyIsRunningInput) == 1 else { return false }
                var addr = address(kAudioProcessPropertyPID)
                var pid: pid_t = 0
                var size = UInt32(MemoryLayout<pid_t>.size)
                guard AudioObjectGetPropertyData(p, &addr, 0, nil, &size, &pid) == noErr, pid != me else { return false }
                return !ignored(string(p, kAudioProcessPropertyBundleID) ?? "")
            }
        }
        // Older macOS: is the default input device running? (Can't tell who's using it.)
        guard let input = ids(system, kAudioHardwarePropertyDefaultInputDevice).first else { return false }
        return uint(input, kAudioDevicePropertyDeviceIsRunningSomewhere) == 1
    }

    /// True while any app has a camera running. Notchfall's own camera check counts too, so callers
    /// ignore this while it's open.
    static var cameraInUse: Bool {
        let sys = CMIOObjectID(kCMIOObjectSystemObject)
        var addr = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
                                             mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                             mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(sys, &addr, 0, nil, &size) == 0, size > 0 else { return false }
        var list = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(sys, &addr, 0, nil, size, &used, &list) == 0 else { return false }
        addr.mSelector = CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere)
        return list.contains { dev in
            var on: UInt32 = 0
            var got: UInt32 = 0
            return CMIOObjectGetPropertyData(dev, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &got, &on) == 0 && on != 0
        }
    }
}

/// Watches for the charger being plugged in and Bluetooth headphones connecting, for the little
/// toasts that pop out of the notch.
final class Peripherals {
    var onCharging: (_ percent: Int) -> Void = { _ in }
    var onHeadphones: (_ name: String) -> Void = { _ in }

    private var onAC: Bool?
    private var known = Set<AudioObjectID>()
    private var powerSource: CFRunLoopSource?

    func start() {
        onAC = Self.power()?.ac
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        if let src = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            Unmanaged<Peripherals>.fromOpaque(ctx).takeUnretainedValue().powerChanged()
        }, ctx)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
            powerSource = src
        }

        known = Set(Devices.audioDevices)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, .main) { [weak self] _, _ in
            self?.devicesChanged()
        }
    }

    private func devicesChanged() {
        let now = Set(Devices.audioDevices)
        let added = now.subtracting(known)
        known = now
        for d in added where Devices.isBluetooth(d) && Devices.hasOutput(d) {
            if let name = Devices.name(d) { onHeadphones(name) }
        }
    }

    private func powerChanged() {
        guard let p = Self.power() else { return }
        if onAC == false, p.ac, let pct = p.percent { onCharging(pct) }
        onAC = p.ac
    }

    /// (on AC power, internal battery %). nil on Macs without a battery.
    static func power() -> (ac: Bool, percent: Int?)? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for src in list {
            guard let d = IOPSGetPowerSourceDescription(info, src)?.takeUnretainedValue() as? [String: Any],
                  d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let ac = d[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            let cur = d[kIOPSCurrentCapacityKey] as? Int, max = d[kIOPSMaxCapacityKey] as? Int
            return (ac, cur.flatMap { c in max.map { m in m > 0 ? c * 100 / m : c } })
        }
        return nil
    }

    static func headphoneSymbol(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("airpods max") { return "airpodsmax" }
        if n.contains("airpods pro") { return "airpodspro" }
        if n.contains("airpods") { return "airpods" }
        if n.contains("beats") { return "beats.headphones" }
        return "headphones"
    }
}
