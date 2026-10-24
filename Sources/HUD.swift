import AppKit
import AudioToolbox
import CoreAudio

/// 🔊 Watches the output volume and the built-in display's brightness, and reports when either is changed,
/// so the level can be shown in the notch. Only reads levels; never changes them.
final class LevelWatch {
    var onChange: (Level) -> Void = { _ in }
    var enabled = true
    private var timer: Timer?
    private var device: AudioObjectID = 0
    private var volume: Double?
    private var muted: Bool?
    private var brightness: Double?

    func start() {
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        // Waking up resets the screen's brightness and sometimes the volume: take the new levels in quietly.
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.volume = nil; self?.brightness = nil; self?.quietUntil = Date().addingTimeInterval(2)
            }
        }
    }
    private var quietUntil = Date.distantPast

    private func poll() {
        guard enabled, Date() >= quietUntil else { volume = nil; brightness = nil; return }
        // A new output device (headphones on, a display's speakers) comes with its own level: take it
        // in quietly rather than flashing it.
        let dev = Self.output
        if dev != device { device = dev; volume = nil; muted = nil }
        if let v = Self.volume(dev) {
            let m = Self.muted(dev)
            if let old = volume, let wasMuted = muted, abs(v - old) >= 0.01 || m != wasMuted {
                onChange(Level(kind: .volume, value: v, muted: m))
            }
            volume = v
            muted = m
        }
        // Compared with the last read only a quarter of a second ago: auto-brightness drifts by far less
        // than that, while the brightness keys jump by a sixteenth at a time.
        if let b = Brightness.level {
            if let old = brightness, abs(b - old) >= 0.04 { onChange(Level(kind: .brightness, value: b)) }
            brightness = b
        } else {
            brightness = nil   // lid closed: start afresh when it opens
        }
    }

    private static var output: AudioObjectID {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var dev = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        return AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev) == noErr ? dev : 0
    }

    private static func volume(_ dev: AudioObjectID) -> Double? {
        guard dev != 0 else { return nil }
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                                              mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(dev, &addr) else { return nil }
        var v = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &v) == noErr ? Double(v) : nil
    }

    private static func muted(_ dev: AudioObjectID) -> Bool {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute,
                                              mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(dev, &addr) else { return false }
        var v = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &v) == noErr && v == 1
    }
}

/// The built-in display's brightness, read through DisplayServices (the framework the brightness keys
/// use). It isn't public, so it's looked up at run time; without it the brightness bar simply never shows.
enum Brightness {
    private typealias Get = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private static let get: Get? = {
        guard let h = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let sym = dlsym(h, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(sym, to: Get.self)
    }()

    private static var builtIn: CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 8)
        var n: UInt32 = 0
        guard CGGetOnlineDisplayList(8, &ids, &n) == .success else { return nil }
        return ids.prefix(Int(n)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    static var level: Double? {
        guard let get, let id = builtIn else { return nil }
        var v = Float(0)
        return get(id, &v) == 0 ? Double(v) : nil
    }
}
