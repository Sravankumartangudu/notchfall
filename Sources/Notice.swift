import AppKit
import SwiftUI

/// 🔔 Something worth a glance that isn't on the calendar: Claude finished, an app stopped, a signal
/// changed. It drops out of the notch as a card and folds itself away after a few seconds.
struct Notice: Equatable, Identifiable {
    var id = UUID().uuidString
    var source: String               // "Claude Code", "Downloads", …: the card's header
    var symbol: String
    var tint: Color
    var title: String
    var detail = ""
    var perform: Perform? = nil      // what the main button does
    var action: String? = nil        // …and its label ("Open", "Relaunch")
    var sticky = false               // stays until dismissed
    var shown = Date()

    static let lifetime: Double = 9

    enum Perform: Equatable {
        case open(URL)                   // a link, a file or an app
        case reveal(URL)                 // show a file in Finder
        case quit(bundleId: String)      // quit another app
        case named(String)               // something the edition handles itself
    }
}

/// ⏳ Something in progress, in the wings: a ring on the left that fills up, a short label on the right.
struct Activity: Equatable, Identifiable {
    var id: String
    var symbol: String
    var tint: Color
    var label: String
    var progress: Double?            // 0…1, or nil while the size isn't known
}

/// 🔊 Volume or ☀️ brightness, while it's being changed.
struct Level: Equatable {
    enum Kind { case volume, brightness }
    var kind: Kind
    var value: Double
    var muted = false
}

struct NoticeContent: View {
    @ObservedObject var m: IslandModel
    let notice: Notice
    let inset: CGFloat

    var body: some View {
        let on = m.showContent
        let tint = notice.tint
        VStack(alignment: .leading, spacing: 0) {
            Wings(m: m) {
                HStack(spacing: 6) {
                    Image(systemName: notice.symbol).font(.system(size: 10, weight: .bold))
                    Text(notice.source.uppercased()).kerning(0.6).lineLimit(1)
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .reveal(on, 0.02)
            } right: {
                Text(notice.shown.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
                    .reveal(on, 0.05)
            }

            HStack(alignment: .center, spacing: 14) {
                Image(systemName: notice.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(tint.opacity(0.16)))
                    .overlay(Circle().strokeBorder(tint.opacity(0.35), lineWidth: 1))
                    .symbolEffect(.bounce, value: on)
                    .reveal(on, 0.04)
                VStack(alignment: .leading, spacing: 4) {
                    Text(notice.title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if !notice.detail.isEmpty {
                        Text(notice.detail)
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(2)
                    }
                }
                .reveal(on, 0.08)
                Spacer(minLength: 0)
            }
            .padding(.top, 8)

            Spacer(minLength: 10)

            HStack(spacing: 8) {
                Button { m.onNotice(notice, false) } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(IslandButtonStyle())
                .help("Dismiss")
                Spacer()
                if !notice.sticky {
                    // Drains over the card's lifetime, so you can see it'll tidy itself away.
                    TimelineView(.animation) { tl in
                        let f = max(0, 1 - tl.date.timeIntervalSince(notice.shown) / Notice.lifetime)
                        Circle().trim(from: 0, to: f).stroke(tint.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90)).frame(width: 14, height: 14)
                    }
                }
                if notice.perform != nil {
                    Button { m.onNotice(notice, true) } label: {
                        Label(notice.action ?? "Open", systemImage: "arrow.up.forward.app.fill")
                    }
                    .buttonStyle(IslandButtonStyle(fill: tint, ink: .black, prominent: true))
                } else {
                    Button { m.onNotice(notice, false) } label: { Label("OK", systemImage: "checkmark") }
                        .buttonStyle(IslandButtonStyle(fill: tint, ink: .black, prominent: true))
                }
            }
            .reveal(on, 0.13)
        }
        .padding(.horizontal, inset)
        .padding(.bottom, 16)
    }
}

struct ActivityContent: View {
    @ObservedObject var m: IslandModel
    let activity: Activity
    let inset: CGFloat

    var body: some View {
        Wings(m: m) {
            ProgressRing(symbol: activity.symbol, tint: activity.tint, progress: activity.progress)
                .reveal(m.showContent)
        } right: {
            Text(activity.label)
                .font(.system(size: 12.5, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(activity.tint)
                .lineLimit(1)
                .contentTransition(.numericText())
                .reveal(m.showContent, 0.04)
        }
        .padding(.horizontal, inset)
    }
}

/// A ring that fills with the progress, or spins while the total isn't known.
private struct ProgressRing: View {
    let symbol: String
    let tint: Color
    let progress: Double?

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.22), lineWidth: 2.4)
            if let p = progress {
                Circle().trim(from: 0, to: max(0.03, p))
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: p)
            } else {
                TimelineView(.animation) { tl in
                    Circle().trim(from: 0, to: 0.28)
                        .stroke(tint, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                        .rotationEffect(.degrees(tl.date.timeIntervalSinceReferenceDate * 300))
                }
            }
            Image(systemName: symbol).font(.system(size: 9, weight: .heavy)).foregroundStyle(tint)
        }
        .frame(width: 21, height: 21)
    }
}

struct LevelContent: View {
    @ObservedObject var m: IslandModel
    let level: Level
    let inset: CGFloat

    var body: some View {
        let tint: Color = level.kind == .brightness ? rgb(1, 0.82, 0.35) : .white
        let v = level.muted ? 0 : level.value
        Wings(m: m) {
            Group {
                if level.kind == .brightness {
                    Image(systemName: v < 0.5 ? "sun.min.fill" : "sun.max.fill")
                } else if level.muted || v == 0 {
                    Image(systemName: "speaker.slash.fill")
                } else {
                    Image(systemName: "speaker.wave.3.fill", variableValue: v)
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(level.muted ? rgb(1, 0.3, 0.32) : tint)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 22)
            .reveal(m.showContent)
        } right: {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.16))
                    Capsule().fill(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, g.size.width * v))
                        .shadow(color: tint.opacity(0.6), radius: 4)
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.85), value: v)
            }
            .frame(width: 78, height: 6)
            .reveal(m.showContent, 0.04)
        }
        .padding(.horizontal, inset)
    }
}

/// 📮 Lets anything post to the notch: drop a JSON file in ~/.notchfall/inbox (scripts, Claude Code hooks).
///   {"title": "Build finished", "detail": "Notchfall · 42 s", "symbol": "hammer.fill", "url": "https://…"}
/// Add "progress" (0…1) and an "id" to show a live activity in the wings instead, and "done": true to end it.
/// Files whose names start with a dot are still being written and are left alone; read files are deleted,
/// and ones more than 10 minutes old are dropped unread.
enum Inbox {
    static let folder = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".notchfall/inbox")

    static func drain() -> [[String: Any]] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: folder.path) else { return [] }
        var out: [[String: Any]] = []
        for name in names.sorted() where name.hasSuffix(".json") && !name.hasPrefix(".") {
            let url = folder.appendingPathComponent(name)
            defer { try? fm.removeItem(at: url) }
            // Anything left from while the app wasn't running is old news.
            if let d = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               Date().timeIntervalSince(d) > 600 { continue }
            guard let data = try? Data(contentsOf: url),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            out.append(obj)
        }
        return out
    }

    /// A tint from "#ff8800", or one of a few names.
    static func color(_ s: String?) -> Color? {
        guard let s = s?.lowercased() else { return nil }
        let named: [String: Color] = ["red": rgb(1, 0.32, 0.34), "orange": rgb(1, 0.6, 0.3), "yellow": rgb(1, 0.84, 0.3),
                                      "green": rgb(0.3, 0.9, 0.48), "blue": rgb(0.36, 0.64, 1), "purple": rgb(0.72, 0.5, 1),
                                      "pink": rgb(1, 0.45, 0.7), "white": .white]
        if let c = named[s] { return c }
        let hex = s.hasPrefix("#") ? String(s.dropFirst()) : s
        guard hex.count == 6, let v = UInt32(hex, radix: 16) else { return nil }
        return rgb(Double(v >> 16 & 0xff) / 255, Double(v >> 8 & 0xff) / 255, Double(v & 0xff) / 255)
    }
}
