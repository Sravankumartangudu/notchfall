import AppKit
import SwiftUI

/// ⚖️ Dharalu's buy / hold / sell calls: when the signal for wheat or a metal changes, it drops out of
/// the notch. Reads the state file the Dharalu agent writes (~/Dharalu/data/state.json); never trades.
final class Dharalu {
    var onChange: (Notice) -> Void = { _ in }
    var enabled = true
    private var signals: [String: String]?
    private var stamp: Date?
    private var timer: Timer?

    private static let data = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Dharalu/data")
    private static let state = data.appendingPathComponent("state.json")
    static let bundleId = "com.sravankumartangudu.dharalu"
    static var installed: Bool { FileManager.default.fileExists(atPath: state.path) }

    func start() {
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        poll()
    }

    private func poll() {
        guard let mod = try? Self.state.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
              mod != stamp else { return }
        stamp = mod
        guard let data = try? Data(contentsOf: Self.state),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        var now: [String: String] = [:]
        for (asset, v) in root {
            if let signal = (v as? [String: Any])?["signal"] as? String { now[asset] = signal }
        }
        // The first read only learns where things stand.
        if let before = signals, enabled {
            for (asset, signal) in now.sorted(by: { $0.key < $1.key }) {
                if let old = before[asset], old != signal {
                    onChange(Self.notice(asset: asset, from: old, to: signal, price: Self.price(asset)))
                }
            }
        }
        signals = now
    }

    /// The latest price, from the last line of the asset's signal log.
    private static func price(_ asset: String) -> String? {
        let file = data.appendingPathComponent(asset == "wheat" ? "signals_log.csv" : "signals_\(asset).csv")
        guard let text = try? String(contentsOf: file, encoding: .utf8),
              let last = text.split(separator: "\n").last?.split(separator: ","), last.count >= 4,
              let p = Double(last[3]) else { return nil }
        return p.formatted(.number.precision(.fractionLength(0)))
    }

    static func notice(asset: String, from: String, to: String, price: String?) -> Notice {
        let tint = to == "BUY" ? rgb(0.3, 0.9, 0.48) : to == "SELL" ? rgb(1, 0.4, 0.38) : rgb(1, 0.78, 0.3)
        let symbol = to == "BUY" ? "arrow.up.right.circle.fill" : to == "SELL" ? "arrow.down.right.circle.fill" : "pause.circle.fill"
        let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
        return Notice(source: "Dharalu", symbol: symbol, tint: tint, title: "\(asset.capitalized): \(from) → \(to)",
                      detail: price.map { "Latest price ₹\($0)  ·  open Dharalu for the proofs" } ?? "Open Dharalu for the proofs",
                      perform: app.map { .open($0) }, action: app == nil ? nil : "Open Dharalu")
    }
}
