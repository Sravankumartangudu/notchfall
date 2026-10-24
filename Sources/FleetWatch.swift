import AppKit
import SwiftUI

/// 🛰 Your other apps, as the fleet monitor sees them: when one quits unexpectedly, stops responding or
/// reports an error, the notch says so. Reads the summary the monitor (Nexus) writes to
/// ~/.nexus/fleet/<parent>.json. Without the monitor installed this does nothing.
final class FleetWatch {
    struct App: Equatable {
        let id, name, status, detail: String
    }

    var onProblem: (App) -> Void = { _ in }
    var enabled = true
    private var apps: [String: App] = [:]
    private var seeded = false
    private var badSince: [String: (status: String, at: Date)] = [:]
    private var told = Set<String>()
    private var stamp: Date?
    private var timer: Timer?
    private let file: URL

    init(parent: String) {
        file = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".nexus/fleet/\(parent).json")
    }

    func start() {
        let t = Timer(timeInterval: 15, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        poll()
    }

    static let bad: Set<String> = ["crashed", "stale", "error"]
    /// A problem has to last this long before it's news: after the Mac wakes, heartbeats are late for a
    /// moment and every app briefly looks stuck.
    static let settle: TimeInterval = 30

    private func poll() {
        read()
        let now = Date()
        for app in apps.values.sorted(by: { $0.name < $1.name }) {
            guard Self.bad.contains(app.status) else { badSince[app.id] = nil; told.remove(app.id); continue }
            if badSince[app.id]?.status != app.status {
                badSince[app.id] = (app.status, now)
                // An app that was already down when we started watching isn't news.
                if seeded { told.remove(app.id) } else { told.insert(app.id) }
            }
            if let since = badSince[app.id]?.at, now.timeIntervalSince(since) >= Self.settle, !told.contains(app.id) {
                told.insert(app.id)
                if enabled { onProblem(app) }
            }
        }
        for id in badSince.keys where apps[id] == nil { badSince[id] = nil; told.remove(id) }
        seeded = true
    }

    private func read() {
        guard let mod = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
              mod != stamp else { return }
        stamp = mod
        guard let data = try? Data(contentsOf: file),
              let list = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["apps"] as? [[String: Any]] else { return }
        var now: [String: App] = [:]
        for a in list {
            guard let id = a["id"] as? String, id != Bundle.main.bundleIdentifier else { continue }
            now[id] = App(id: id, name: a["name"] as? String ?? id, status: a["status"] as? String ?? "",
                          detail: a["detail"] as? String ?? "")
        }
        apps = now
    }

    static func notice(_ app: App) -> Notice {
        let (title, symbol, tint): (String, String, Color) = switch app.status {
        case "crashed": ("\(app.name) quit unexpectedly", "exclamationmark.octagon.fill", rgb(1, 0.36, 0.38))
        case "stale": ("\(app.name) isn't responding", "hourglass", rgb(1, 0.66, 0.25))
        default: ("\(app.name) needs a look", "exclamationmark.triangle.fill", rgb(1, 0.5, 0.32))
        }
        let relaunch = app.status == "crashed" ? NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.id) : nil
        return Notice(source: "Fleet", symbol: symbol, tint: tint, title: title, detail: app.detail,
                      perform: relaunch.map { .open($0) }, action: relaunch == nil ? nil : "Relaunch", sticky: true)
    }
}
