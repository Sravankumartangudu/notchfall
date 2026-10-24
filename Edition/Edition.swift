import AppKit

/// What makes this copy of Notchfall the personal one. Everything in Sources/ is shared with other
/// editions; anything that only belongs here lives in this folder.
enum Edition {
    static let name = "Notchfall"
    /// The fleet monitor whose summary (~/.nexus/fleet/<file>.json) the 🛰 fleet alerts read.
    static let fleetFile = "nexus", fleetName = "Nexus"

    private static let dharalu = Dharalu()
    private static let target = Target()

    /// Starts the personal watchers. Not called for screenshot runs.
    static func setUp(_ app: AppDelegate) {
        dharalu.onChange = { app.post($0) }
        dharalu.enabled = UserDefaults.standard.object(forKey: "dharaluAlerts") as? Bool ?? true
        dharalu.start()
    }

    /// Extra lines in the menu, under the shelf and the clipboard.
    static func addMenuItems(to menu: NSMenu, _ app: AppDelegate) {}

    /// A section of its own in ⚙ Settings.
    static func addSettings(to prefs: NSMenu, _ app: AppDelegate) {
        guard Dharalu.installed else { return }
        prefs.addItem(.separator())
        prefs.addItem(app.sectionHeader("Dharalu"))
        let mi = NSMenuItem(title: "Buy / hold / sell signal changes", action: #selector(Target.toggleDharalu), keyEquivalent: "")
        mi.target = target
        mi.state = dharalu.enabled ? .on : .off
        prefs.addItem(mi)
    }

    static let previews: [(String, String)] = [("Dharalu signal change", "-dharalu")]

    static func preview(_ which: String, _ app: AppDelegate) -> Bool {
        guard which == "-dharalu" else { return false }
        app.post(Dharalu.notice(asset: "wheat", from: "HOLD", to: "BUY", price: "2,950"))
        return true
    }

    /// The main button of a notice that asked for something only this edition knows how to do.
    static func perform(_ name: String, _ app: AppDelegate) {}

    private final class Target: NSObject {
        @objc func toggleDharalu() {
            dharalu.enabled.toggle()
            UserDefaults.standard.set(dharalu.enabled, forKey: "dharaluAlerts")
        }
    }
}
