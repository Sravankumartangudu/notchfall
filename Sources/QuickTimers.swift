import AppKit

/// One-off countdown reminders started from the menu ("Remind me in 25 min"), and the 🍅 focus
/// session (focus, break, focus…). Saved to UserDefaults so they survive a restart.
final class QuickTimers {
    struct Item: Codable {
        let id: String
        let title: String
        var due: Date
        // Focus sessions only (nil for plain timers, and for timers saved by older versions).
        var phase: String? = nil        // "focus" or "break"
        var focusMinutes: Int? = nil
        var breakMinutes: Int? = nil

        var isFocus: Bool { phase != nil }
        var minutes: Int { (phase == "break" ? breakMinutes : focusMinutes) ?? 0 }
    }

    private let key = "quickTimers"
    private(set) var items: [Item] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([Item].self, from: data) {
            // Drop timers that went off long ago while the app wasn't running.
            items = saved.filter { $0.due > Date().addingTimeInterval(-300) }
        }
    }

    var meetings: [Meeting] {
        items.map {
            Meeting(id: $0.id, title: $0.title, start: $0.due, end: $0.due.addingTimeInterval(300),
                    link: nil, calendar: $0.phase == "break" ? "Break" : $0.isFocus ? "Focus" : "Quick timer",
                    attendees: 0, kind: $0.isFocus ? .focus : .timer, minutes: $0.minutes)
        }
    }

    var plain: [Item] { items.filter { !$0.isFocus } }
    var focus: Item? { items.first { $0.isFocus } }
    func item(_ id: String) -> Item? { items.first { $0.id == id } }

    /// Starts a focus (or break) stretch, replacing any running one: there's only ever one session.
    func startFocus(_ phase: String, focus: Int, rest: Int) {
        items.removeAll { $0.isFocus }
        let minutes = phase == "break" ? rest : focus
        items.append(Item(id: "focus-\(UUID().uuidString)", title: phase == "break" ? "Break's over" : "Focus session done",
                          due: Date().addingTimeInterval(Double(minutes) * 60),
                          phase: phase, focusMinutes: focus, breakMinutes: rest))
        save()
    }

    func stopFocus() {
        items.removeAll { $0.isFocus }
        save()
    }

    func extend(_ id: String, by seconds: Double) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].due = max(items[i].due, Date()).addingTimeInterval(seconds)
        save()
    }

    func add(minutes: Int, title: String) {
        items.append(Item(id: "timer-\(UUID().uuidString)", title: title,
                          due: Date().addingTimeInterval(Double(minutes) * 60)))
        save()
    }

    func remove(_ id: String) {
        items.removeAll { $0.id == id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: key) }
    }

    /// Asks for a label and duration. Re-asks until the minutes are valid; nil if cancelled.
    static func prompt() -> (title: String, minutes: Int)? {
        var title = "", minutes = "25", error: String?
        while true {
            guard let r = ask(title: title, minutes: minutes, error: error) else { return nil }
            (title, minutes) = (r.title, r.minutes)
            if let m = Int(minutes.trimmingCharacters(in: .whitespaces)), m > 0, m <= 24 * 60 {
                let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                return (t.isEmpty ? "\(m)-min timer" : t, m)
            }
            error = "“\(minutes)” isn't valid. Enter whole minutes from 1 to 1440 (24 hours)."
        }
    }

    private static func ask(title: String, minutes: String, error: String?) -> (title: String, minutes: String)? {
        let alert = NSAlert()
        alert.messageText = "New quick timer"
        alert.informativeText = error ?? "Notchfall drops an alert out of the notch when the time is up."

        let label = NSTextField(frame: NSRect(x: 0, y: 32, width: 260, height: 24))
        label.placeholderString = "What's it for? (e.g. Stretch break)"
        label.stringValue = title
        let mins = NSTextField(frame: NSRect(x: 0, y: 0, width: 80, height: 24))
        mins.stringValue = minutes
        let unit = NSTextField(labelWithString: "minutes")
        unit.frame = NSRect(x: 88, y: 3, width: 100, height: 18)
        let box = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 56))
        [label, mins, unit].forEach(box.addSubview)
        alert.accessoryView = box
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = error == nil ? label : mins

        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return (label.stringValue, mins.stringValue)
    }
}
