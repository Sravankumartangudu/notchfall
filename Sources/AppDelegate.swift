import AppKit
import AVFoundation
import EventKit
import ServiceManagement
import SwiftUI

final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    var leadMinutes: Int {
        get { d.object(forKey: "leadMinutes") as? Int ?? 2 }
        set { d.set(newValue, forKey: "leadMinutes") }
    }
    /// Minutes before the start that the live countdown peeks out beside the notch. 0 = off.
    var peekMinutes: Int {
        get { d.object(forKey: "peekMinutes") as? Int ?? 10 }
        set { d.set(newValue, forKey: "peekMinutes") }
    }
    var hover: Bool {
        get { d.object(forKey: "hover") as? Bool ?? true }
        set { d.set(newValue, forKey: "hover") }
    }
    var glow: Glow {
        get { Glow(rawValue: d.string(forKey: "glow") ?? "") ?? .aurora }
        set { d.set(newValue.rawValue, forKey: "glow") }
    }
    /// A system sound name, or "off".
    var sound: String {
        get { d.string(forKey: "sound") ?? "Glass" }
        set { d.set(newValue, forKey: "sound") }
    }
    var voice: Bool {
        get { d.object(forKey: "voice") as? Bool ?? false }
        set { d.set(newValue, forKey: "voice") }
    }
    var videoOnly: Bool {
        get { d.object(forKey: "videoOnly") as? Bool ?? false }
        set { d.set(newValue, forKey: "videoOnly") }
    }
    var reminders: Bool {
        get { d.object(forKey: "reminders") as? Bool ?? false }
        set { d.set(newValue, forKey: "reminders") }
    }
    /// On-air indicator: "off", "meetings" (only on a call during a calendar meeting) or "always"
    /// (whenever another app has the mic or camera on).
    var onAir: String {
        get { d.string(forKey: "onAir") ?? "meetings" }
        set { d.set(newValue, forKey: "onAir") }
    }
    /// "notch" (built-in notch screen, else the main screen) or "primary" (the screen with the menu bar).
    var screen: String {
        get { d.string(forKey: "screen") ?? "notch" }
        set { d.set(newValue, forKey: "screen") }
    }
    /// "system" (follow macOS), "light" or "dark". Affects menus and dialogs only; the island is always black.
    var appearance: String {
        get { d.string(forKey: "appearance") ?? "system" }
        set { d.set(newValue, forKey: "appearance"); applyAppearance() }
    }
    func applyAppearance() {
        switch appearance {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let cal = CalendarService()
    private var island: IslandController!
    private let synth = AVSpeechSynthesizer()
    private let settings = Settings.shared
    private var statusItem: NSStatusItem!
    private var timer: Timer?

    private var meetings: [Meeting] = []
    private var reminders: [Meeting] = []
    private let timers = QuickTimers()
    // Read live so the warning clears once access is granted in System Settings.
    private var remindersDenied: Bool { ![.fullAccess, .notDetermined].contains(cal.remindersStatus) }
    private var demo: Meeting?
    private var demoAgenda: [Meeting]?
    private var alerted = Set<String>()
    private var handled = Set<String>()
    private var snoozed: [String: Date] = [:]
    private var lastRefresh = Date.distantPast
    private var accessDenied = false
    private var joined: Meeting?           // the meeting last joined from Notchfall
    private var deviceOnSince: Date?       // mic/camera debouncing for the on-air indicator
    private var deviceOffSince: Date?
    private var demoOnAir: (OnAir, until: Date)?

    private static let sounds = ["Glass", "Hero", "Ping", "Pop", "Purr", "Submarine", "Tink"]

    private var relevant: [Meeting] {
        // The video-link filter only applies to calendar events; reminders and timers always count.
        let events = settings.videoOnly ? meetings.filter { $0.link != nil } : meetings
        let extras = (settings.reminders ? reminders : []) + timers.meetings
        return (events + extras + [demo].compactMap { $0 }).sorted { $0.start < $1.start }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings.applyAppearance()
        island = IslandController()
        applyIslandSettings()
        island.model.onAction = { [weak self] action, m in self?.handle(action, for: m) }
        island.model.onJoin = { m in if let url = m.link { NSWorkspace.shared.open(url) } }
        island.model.snoozeLabel = { m in m.kind == .meeting ? "Snooze 1 min" : "Snooze 5 min" }
        island.model.onMirror = { [weak self] open in self?.island.setMirror(open) }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = Self.menuIcon()
        statusItem.button?.imagePosition = .imageLeading
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        NexusBeacon.start(name: "Notchfall") { [weak self] in
            guard let self else { return ("ok", "") }
            if self.accessDenied { return ("warn", "calendar access denied") }
            if let next = self.relevant.first(where: { $0.start > Date() }) {
                return ("ok", "next: \(countdown(next.start, now: Date(), short: true))")
            }
            return ("ok", "nothing scheduled")
        }
        NexusBeacon.attach(statusItem)   // lets the app live in Nexus's menu
        updateTitle()

        cal.requestAccess { [weak self] ok in
            self?.accessDenied = !ok
            self?.refresh()
        }
        if settings.reminders { enableReminders() }
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: cal.store, queue: .main) { [weak self] _ in
            self?.refresh()
        }

        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        // --demo (meeting), --demo-tour, --demo-reminder, --demo-timer, --demo-live, --demo-peek, --demo-list,
        // --demo-mirror, --demo-onair: previews for docs.
        if let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--demo") }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.runDemo(String(arg.dropFirst("--demo".count))) }
        }
    }

    private func applyIslandSettings() {
        island.hoverEnabled = settings.hover
        island.peekEnabled = settings.peekMinutes > 0
        island.model.peekWindow = Double(max(1, settings.peekMinutes) * 60)
        island.model.lead = Double(max(1, settings.leadMinutes) * 60)
        island.model.glow = settings.glow
        if island.screenChoice != settings.screen {
            island.screenChoice = settings.screen
            island.place()
        }
        island.resolve()
    }

    // MARK: - Scheduling

    private func refresh() {
        meetings = cal.upcoming()
        lastRefresh = Date()
        if settings.reminders {
            cal.upcomingReminders { [weak self] list in
                self?.reminders = list
                self?.updateTitle()
            }
        }
        updateTitle()
    }

    private func tick() {
        if Date().timeIntervalSince(lastRefresh) > 60 { refresh() }
        updateTitle()
        updateIsland()
        updateOnAir()
        // Wait while an alert is up or a dialog (e.g. "New timer…") is open.
        guard !island.isShowingAlert, NSApp.modalWindow == nil else { return }

        let now = Date()
        for m in relevant where !handled.contains(m.id) {
            // Meetings warn ahead of time; reminders and timers fire when they're due.
            let lead = m.kind == .meeting ? Double(settings.leadMinutes * 60) : 0
            // How late an alert may still fire (e.g. after the Mac wakes from sleep). A meeting
            // is pointless after 5 minutes, but a timer should always say "time's up".
            let grace: Double
            switch m.kind {
            case .meeting: grace = 300
            case .reminder: grace = 3600
            case .timer: grace = .infinity
            }
            if let until = snoozed[m.id] {
                if now >= until {
                    snoozed[m.id] = nil
                    return present(m)
                }
                continue
            }
            let remaining = m.start.timeIntervalSince(now)
            if !alerted.contains(m.id), remaining <= lead, remaining > -grace {
                alerted.insert(m.id)
                return present(m)
            }
        }
    }

    /// Feeds the island its clock, the "Up next" list and the item for the live countdown.
    private func updateIsland() {
        let now = Date()
        let model = island.model
        withAnimation(.snappy(duration: 0.35)) { model.now = now }

        let agenda = demoAgenda ?? Array(relevant.filter { $0.end > now && !handled.contains($0.id) }.prefix(4))
        if agenda.map(\.id) != model.agenda.map(\.id) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { model.agenda = agenda }
        }

        let window = Double(settings.peekMinutes * 60)
        let peek = relevant.first { m in
            !handled.contains(m.id) && snoozed[m.id] == nil && m.id != model.alert?.id
                && m.start.timeIntervalSince(now) <= window && m.start.timeIntervalSince(now) > -60
        }
        if peek?.id != model.peek?.id {
            model.peek = peek
            island.resolve()
        }
    }

    /// Shows the on-air island while you're on a call. The mic/camera has to stay on for 2 s before it
    /// appears and off for 6 s before it goes, so switching devices or a quick dictation doesn't flicker it.
    private func updateOnAir() {
        let now = Date()
        let model = island.model
        if let (demoAir, until) = demoOnAir {
            if now < until { return setOnAir(demoAir) }
            demoOnAir = nil
        }
        guard settings.onAir != "off" else { return setOnAir(nil) }

        let mic = Devices.micInUse
        // Our own camera check lights the camera too; that isn't a call.
        let cam = island.mirrorOpen ? false : Devices.cameraInUse
        if mic || cam {
            deviceOffSince = nil
            if deviceOnSince == nil { deviceOnSince = now }
        } else if deviceOnSince != nil {
            if deviceOffSince == nil { deviceOffSince = now }
            if now.timeIntervalSince(deviceOffSince!) > 6 { deviceOnSince = nil; deviceOffSince = nil }
        }
        guard let since = deviceOnSince, now.timeIntervalSince(since) >= 2 else { return setOnAir(nil) }

        // The call's meeting: the one joined from Notchfall, else a calendar meeting that's on now
        // (or starts within 5 minutes, for people who join early).
        if let j = joined, j.end <= now { joined = nil }
        let meetingsNow = relevant.filter { $0.kind == .meeting && $0.end > now && $0.start.timeIntervalSince(now) <= 300 }
        let meeting = joined ?? meetingsNow.first { $0.link != nil } ?? meetingsNow.first
        if meeting == nil && settings.onAir != "always" { return setOnAir(nil) }

        let next = meeting.flatMap { cur in
            relevant.first { $0.kind == .meeting && $0.id != cur.id && !handled.contains($0.id)
                && $0.start >= cur.end.addingTimeInterval(-120) && $0.start <= cur.end.addingTimeInterval(600) }
        }
        let air = OnAir(meeting: meeting, since: model.onAir?.since ?? since,
                        mic: mic || (model.onAir?.mic ?? false) && deviceOffSince != nil,
                        camera: cam, next: next)
        setOnAir(air)
    }

    private func setOnAir(_ air: OnAir?) {
        let model = island.model
        guard air != model.onAir else { return }
        let appearing = (air == nil) != (model.onAir == nil)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { model.onAir = air }
        if appearing { island.resolve() }
    }

    private func present(_ m: Meeting) {
        if settings.sound != "off" { NSSound(named: settings.sound)?.play() }
        if settings.voice {
            let mins = Int((m.start.timeIntervalSinceNow / 60).rounded())
            let plural = mins == 1 ? "" : "s"
            let line: String
            switch m.kind {
            case .meeting: line = "\(m.title) " + (mins <= 0 ? "is starting now." : "starts in \(mins) minute\(plural).")
            case .reminder: line = "Reminder. \(m.title) " + (mins <= 0 ? "is due now." : "is due in \(mins) minute\(plural).")
            case .timer: line = "Time's up. \(m.title)."
            }
            synth.speak(AVSpeechUtterance(string: line))
        }
        island.present(m)
    }

    private func handle(_ action: OverlayAction, for m: Meeting) {
        synth.stopSpeaking(at: .immediate)
        island.closeAlert()
        switch action {
        case .join:
            handled.insert(m.id)
            if m.kind == .meeting, !m.id.hasPrefix("demo-") { joined = m }
            if let url = m.link { NSWorkspace.shared.open(url) }
        case .snooze:
            snoozed[m.id] = Date().addingTimeInterval(m.kind == .meeting ? 60 : 300)
        case .dismiss:
            handled.insert(m.id)
        }
        if m.id == demo?.id, action != .snooze { demo = nil }
        if m.kind == .timer, action != .snooze { timers.remove(m.id) }
        updateIsland()
    }

    // MARK: - Menu bar

    /// Template glyph: the top of a screen with an island hanging from it and a drop falling out.
    static func menuIcon() -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 1, y: 14.6, width: 16, height: 2.2), xRadius: 1.1, yRadius: 1.1).fill()
            NSBezierPath(roundedRect: NSRect(x: 4, y: 8.4, width: 10, height: 7.4), xRadius: 3.4, yRadius: 3.4).fill()
            NSBezierPath(ovalIn: NSRect(x: 7.4, y: 3.2, width: 3.2, height: 3.2)).fill()
            NSBezierPath(ovalIn: NSRect(x: 8.2, y: 0.4, width: 1.6, height: 1.6)).fill()
            return true
        }
        img.isTemplate = true
        return img
    }

    private func updateTitle() {
        guard let button = statusItem?.button else { return }
        let now = Date()
        var text = ""
        if let next = relevant.first(where: { $0.start > now && !handled.contains($0.id) }), next.start.timeIntervalSince(now) < 3600 {
            text = " " + countdown(next.start, now: now, short: true)
        } else if relevant.contains(where: { $0.start <= now && $0.end > now && $0.kind == .meeting }) {
            text = " live"
        }
        button.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
        ])
    }

    private func truncate(_ s: String, _ n: Int = 18) -> String {
        s.count > n ? String(s.prefix(n - 1)) + "…" : s
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(sectionHeader("Notchfall · up next"))

        if accessDenied {
            menu.addItem(item("⚠ Calendar access denied — open Privacy settings", #selector(openPrivacy)))
        }
        if remindersDenied && settings.reminders {
            menu.addItem(item("⚠ Reminders access denied — open Privacy settings", #selector(openRemindersPrivacy)))
        }

        let now = Date()
        let upcoming = relevant.filter { $0.end > now }.prefix(12)
        if upcoming.isEmpty {
            menu.addItem(disabled("Nothing in the next 18 hours"))
        }
        let today = DateFormatter(), later = DateFormatter()
        today.dateFormat = "HH:mm"
        later.dateFormat = "EEE HH:mm"
        for m in upcoming {
            let when = m.start <= now ? "Now" : (Calendar.current.isDateInToday(m.start) ? today : later).string(from: m.start)
            let tag: String
            switch m.kind {
            case .timer: tag = "  ⏱"
            case .reminder: tag = "  ☑"
            case .meeting: tag = m.link == nil ? "" : "  → \(m.provider)"
            }
            let mi = item("\(when)   \(truncate(m.title, 36))\(tag)", m.link == nil ? nil : #selector(joinFromMenu(_:)))
            mi.representedObject = m.link
            menu.addItem(mi)
        }

        menu.addItem(.separator())
        let preview = NSMenu()
        for (label, arg) in [("Take the tour", "-tour"), ("Meeting alert", ""),("Meeting going live", "-live"), ("Reminder alert", "-reminder"),
                             ("Timer alert", "-timer"), ("Live countdown", "-peek"), ("Up next list", "-list"),
                             ("Camera check", "-mirror"), ("On air (during a call)", "-onair")] {
            let mi = item(label, #selector(previewFromMenu(_:)))
            mi.representedObject = arg
            preview.addItem(mi)
        }
        let previewItem = submenu("✨ Preview an alert", preview)
        menu.addItem(previewItem)
        menu.addItem(item("Drop a test alert", #selector(fireTestFromMenu), key: "t"))

        let timerMenu = NSMenu()
        timerMenu.addItem(item("New timer with a label…", #selector(newCustomTimer)))
        timerMenu.addItem(.separator())
        for n in [5, 10, 15, 25, 30, 45, 60] {
            let mi = item("In \(n) min", #selector(newPresetTimer(_:)))
            mi.tag = n
            timerMenu.addItem(mi)
        }
        if !timers.items.isEmpty {
            timerMenu.addItem(.separator())
            timerMenu.addItem(disabled("Running"))
            for t in timers.items {
                let left = max(0, Int(t.due.timeIntervalSince(now) / 60 + 1))
                let mi = item("✕ Cancel “\(truncate(t.title, 28))” (\(left)m left)", #selector(cancelTimer(_:)))
                mi.representedObject = t.id
                timerMenu.addItem(mi)
            }
        }
        menu.addItem(submenu("⏱ Quick timer", timerMenu))

        // All preferences live under one Settings submenu, grouped by what they affect.
        let prefs = NSMenu()
        prefs.addItem(sectionHeader("Island"))
        let leadMenu = NSMenu()
        for n in [1, 2, 3, 5, 10] {
            let mi = item("\(n) min before", #selector(setLead(_:)))
            mi.tag = n
            mi.state = settings.leadMinutes == n ? .on : .off
            leadMenu.addItem(mi)
        }
        prefs.addItem(submenu("Alert drops", leadMenu))

        let peekMenu = NSMenu()
        for n in [0, 5, 10, 15, 30] {
            let mi = item(n == 0 ? "Off" : "From \(n) min before", #selector(setPeek(_:)))
            mi.tag = n
            mi.state = settings.peekMinutes == n ? .on : .off
            peekMenu.addItem(mi)
        }
        prefs.addItem(submenu("Live countdown beside the notch", peekMenu))
        prefs.addItem(toggle("Open “Up next” when hovering the notch", settings.hover, #selector(toggleHover)))
        let airMenu = NSMenu()
        for (raw, label) in [("off", "Off"), ("meetings", "During calendar meetings"), ("always", "Whenever the mic or camera is on")] {
            let mi = item(label, #selector(setOnAirMode(_:)))
            mi.representedObject = raw
            mi.state = settings.onAir == raw ? .on : .off
            airMenu.addItem(mi)
        }
        prefs.addItem(submenu("On air indicator during calls", airMenu))

        let glowMenu = NSMenu()
        for g in Glow.allCases {
            let mi = item(g.label, #selector(setGlow(_:)))
            mi.representedObject = g.rawValue
            mi.state = settings.glow == g ? .on : .off
            glowMenu.addItem(mi)
        }
        prefs.addItem(submenu("Glow colours", glowMenu))

        let screenMenu = NSMenu()
        for (raw, label) in [("notch", "Built-in screen with the notch"), ("primary", "Main screen (menu bar)")] {
            let mi = item(label, #selector(setScreen(_:)))
            mi.representedObject = raw
            mi.state = settings.screen == raw ? .on : .off
            screenMenu.addItem(mi)
        }
        prefs.addItem(submenu("Show on", screenMenu))

        prefs.addItem(.separator())
        prefs.addItem(sectionHeader("Sound"))
        let soundMenu = NSMenu()
        for name in ["off"] + Self.sounds {
            let mi = item(name == "off" ? "Off" : name, #selector(setSound(_:)))
            mi.representedObject = name
            mi.state = settings.sound == name ? .on : .off
            soundMenu.addItem(mi)
        }
        prefs.addItem(submenu("Alert sound", soundMenu))
        prefs.addItem(toggle("Voice announcement", settings.voice, #selector(toggleVoice)))

        prefs.addItem(.separator())
        prefs.addItem(sectionHeader("What to alert for"))
        prefs.addItem(toggle("Only meetings with video links", settings.videoOnly, #selector(toggleVideoOnly)))
        prefs.addItem(toggle("Include Apple Reminders", settings.reminders, #selector(toggleReminders)))

        prefs.addItem(.separator())
        prefs.addItem(sectionHeader("App"))
        let appearanceMenu = NSMenu()
        for (raw, label) in [("system", "System"), ("light", "Light"), ("dark", "Dark")] {
            let mi = item(label, #selector(setAppearance(_:)))
            mi.representedObject = raw
            mi.state = settings.appearance == raw ? .on : .off
            appearanceMenu.addItem(mi)
        }
        prefs.addItem(submenu("Appearance (menu and dialogs)", appearanceMenu))
        prefs.addItem(toggle("Launch at login", SMAppService.mainApp.status == .enabled, #selector(toggleLogin)))
        menu.addItem(submenu("⚙ Settings", prefs))

        menu.addItem(.separator())
        menu.addItem(item("Refresh calendars", #selector(manualRefresh), key: "r"))
        menu.addItem(item("Quit Notchfall", #selector(NSApplication.terminate(_:)), key: "q"))
    }

    private func item(_ title: String, _ action: Selector?, key: String = "") -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: action, keyEquivalent: key)
        mi.target = action == #selector(NSApplication.terminate(_:)) ? NSApp : self
        return mi
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        mi.isEnabled = false
        return mi
    }

    private func sectionHeader(_ title: String) -> NSMenuItem {
        let mi = NSMenuItem(title: title.uppercased(), action: nil, keyEquivalent: "")
        mi.attributedTitle = NSAttributedString(string: title.uppercased(), attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
            .kern: 0.8,
        ])
        mi.isEnabled = false
        return mi
    }

    private func toggle(_ title: String, _ on: Bool, _ action: Selector) -> NSMenuItem {
        let mi = item(title, action)
        mi.state = on ? .on : .off
        return mi
    }

    private func submenu(_ title: String, _ sub: NSMenu) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        mi.submenu = sub
        return mi
    }

    // MARK: - Actions

    @objc private func joinFromMenu(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { NSWorkspace.shared.open(url) }
    }

    @objc private func fireTestFromMenu() { runDemo("") }

    @objc private func previewFromMenu(_ sender: NSMenuItem) {
        runDemo(sender.representedObject as? String ?? "")
    }

    /// "" meeting, "-tour" (everything in a row), "-live", "-reminder", "-timer", "-peek" (countdown beside the notch),
    /// "-list" (Up next), "-mirror" (camera check), "-onair" (on a call).
    private func runDemo(_ which: String) {
        // Don't replace a real alert: it would close without its Join/Snooze/Dismiss handling.
        guard !island.isShowingAlert else { return }
        // Launch-flag previews are for screenshots, so they never turn the real camera on.
        let forDocs = CommandLine.arguments.contains { $0.hasPrefix("--demo") }
        switch which {
        case "-tour":
            // The whole life of an alert in ~16 s: drop out of the notch, camera check, on the call,
            // Up next, live countdown.
            let m = Meeting.demo(startingIn: Double(settings.leadMinutes * 60))
            demo = m
            alerted.insert(m.id)
            present(m)
            island.model.fakeCamera = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
                guard let self, self.island.model.alert?.id == m.id else { return }
                self.island.setMirror(true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    guard self.island.model.alert?.id == m.id else { return }
                    self.handle(.dismiss, for: m)
                    self.island.model.fakeCamera = forDocs
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { self.runDemo("-onair-short") }
                }
            }
        case "-onair", "-onair-short":
            let short = which == "-onair-short"
            let now = Date()
            let m = Meeting.demo(startingIn: -25 * 60 - 30)
            let mt = Meeting(id: m.id, title: m.title, start: m.start, end: now.addingTimeInterval(4 * 60 + 32), link: m.link,
                             calendar: m.calendar, attendees: m.attendees, people: m.people)
            let next = Meeting(id: "demo-next", title: "Sprint Planning", start: mt.end, end: mt.end.addingTimeInterval(3600),
                               link: URL(string: "https://zoom.us/j/1"), calendar: "Preview", attendees: 9)
            demoOnAir = (OnAir(meeting: mt, since: mt.start, mic: true, camera: true, next: next),
                         now.addingTimeInterval(short ? 3.6 : 20))
            updateOnAir()
            if short {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) { [weak self] in
                    self?.updateOnAir()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self?.runDemo("-list-short") }
                }
            }
        case "-mirror":
            let m = Meeting.demo(startingIn: Double(settings.leadMinutes * 60))
            demo = m
            alerted.insert(m.id)
            island.model.fakeCamera = forDocs
            present(m)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard self?.island.model.alert?.id == m.id else { return }
                self?.island.setMirror(true)
            }
        case "-list-short":
            demoAgenda = Meeting.demoAgenda()
            updateIsland()
            island.showListPreview(for: 3.2) { [weak self] in
                self?.demoAgenda = nil
                self?.updateIsland()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self?.runDemo("-peek") }
            }
        case "-peek":
            demo = Meeting.demo(startingIn: 4 * 60 + 12)
            alerted.insert(demo!.id)
            updateIsland()
            // Leave the countdown up for a while, then tidy up.
            let id = demo!.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
                if self?.demo?.id == id { self?.demo = nil; self?.updateIsland() }
            }
        case "-list":
            demoAgenda = Meeting.demoAgenda()
            updateIsland()
            island.showListPreview(for: 12) { [weak self] in
                self?.demoAgenda = nil
                self?.updateIsland()
            }
        default:
            let kind: Meeting.Kind = which == "-reminder" ? .reminder : which == "-timer" ? .timer : .meeting
            let live = which == "-live" || kind != .meeting
            let m = Meeting.demo(startingIn: live ? -1 : Double(settings.leadMinutes * 60), kind: kind)
            demo = m
            alerted.insert(m.id)
            present(m)
        }
    }

    @objc private func setLead(_ sender: NSMenuItem) { settings.leadMinutes = sender.tag; applyIslandSettings() }
    @objc private func setPeek(_ sender: NSMenuItem) { settings.peekMinutes = sender.tag; applyIslandSettings(); updateIsland() }
    @objc private func toggleHover() { settings.hover.toggle(); applyIslandSettings() }

    @objc private func setGlow(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let g = Glow(rawValue: raw) { settings.glow = g }
        applyIslandSettings()
    }

    @objc private func setOnAirMode(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String { settings.onAir = raw }
        updateOnAir()
    }

    @objc private func setScreen(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String { settings.screen = raw }
        applyIslandSettings()
    }

    @objc private func setSound(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        settings.sound = name
        if name != "off" { NSSound(named: name)?.play() }
    }

    @objc private func setAppearance(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String { settings.appearance = raw }
    }

    @objc private func toggleVoice() { settings.voice.toggle() }
    @objc private func toggleVideoOnly() { settings.videoOnly.toggle(); updateIsland() }
    @objc private func manualRefresh() { refresh() }

    @objc private func toggleReminders() {
        settings.reminders.toggle()
        if settings.reminders { enableReminders() } else { reminders = []; updateTitle() }
    }

    private func enableReminders() {
        cal.requestRemindersAccess { [weak self] _ in self?.refresh() }
    }

    @objc private func newPresetTimer(_ sender: NSMenuItem) {
        timers.add(minutes: sender.tag, title: "\(sender.tag)-min timer")
        updateTitle()
    }

    @objc private func newCustomTimer() {
        guard let (title, minutes) = QuickTimers.prompt() else { return }
        timers.add(minutes: minutes, title: title)
        updateTitle()
    }

    @objc private func cancelTimer(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { timers.remove(id) }
        updateTitle()
    }

    @objc private func openRemindersPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Notchfall: launch-at-login change failed: \(error)")
        }
    }

    @objc private func openPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
