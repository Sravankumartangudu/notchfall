import SwiftUI

/// ⚡ Charging / 🎧 headphones connected: a few seconds in the wings, then gone.
struct ToastContent: View {
    @ObservedObject var m: IslandModel
    let toast: Toast
    let inset: CGFloat

    var body: some View {
        let on = m.showContent
        Wings(m: m) {
            switch toast.kind {
            case .charging(let pct):
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(pct <= 20 ? rgb(1, 0.75, 0.25) : rgb(0.3, 0.92, 0.45))
                        .symbolEffect(.bounce, value: on)
                    Text("Charging").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                }
                .reveal(on)
            case .headphones(let name):
                Image(systemName: Peripherals.headphoneSymbol(name))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: on)
                    .reveal(on)
            }
        } right: {
            switch toast.kind {
            case .charging(let pct):
                HStack(spacing: 6) {
                    Text("\(pct)%").font(.system(size: 12.5, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                    BatteryGlyph(percent: pct, filling: on)
                }
                .reveal(on, 0.04)
            case .headphones(let name):
                HStack(spacing: 5) {
                    Text(name).lineLimit(1).foregroundStyle(.white.opacity(0.9))
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(rgb(0.3, 0.92, 0.45))
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .reveal(on, 0.04)
            }
        }
        .padding(.horizontal, inset)
    }
}

/// A battery outline whose green fill sweeps up to the current charge.
private struct BatteryGlyph: View {
    let percent: Int
    let filling: Bool

    var body: some View {
        let tint = percent <= 20 ? rgb(1, 0.75, 0.25) : rgb(0.3, 0.92, 0.45)
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous).stroke(.white.opacity(0.45), lineWidth: 1)
                RoundedRectangle(cornerRadius: 2, style: .continuous).fill(tint)
                    .frame(width: max(2, 20 * CGFloat(filling ? percent : 0) / 100))
                    .padding(2)
                    .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.15), value: filling)
            }
            .frame(width: 26, height: 13)
            RoundedRectangle(cornerRadius: 1).fill(.white.opacity(0.45)).frame(width: 2, height: 5)
        }
    }
}

/// 🍅 Focus session in the wings: a draining tomato ring on the left, minutes and seconds on the right.
struct FocusContent: View {
    @ObservedObject var m: IslandModel
    let item: Meeting
    let inset: CGFloat

    var body: some View {
        let tint = item.isBreak ? rgb(0.45, 0.85, 0.95) : item.kind.tint(m.glow)
        let left = max(0, item.start.timeIntervalSince(m.now))
        let total = Double(max(1, item.minutes) * 60)
        Wings(m: m) {
            CountdownBadge(symbol: item.symbol, tint: tint, progress: min(1, left / total), live: false, size: 22)
                .reveal(m.showContent)
        } right: {
            let s = Int(ceil(left))
            Text(String(format: "%d:%02d", s / 60, s % 60))
                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(tint)
                .contentTransition(.numericText(countsDown: true))
                .reveal(m.showContent, 0.04)
        }
        .padding(.horizontal, inset)
    }
}

/// ☀️ Good morning: how many meetings today, the first one, reminders due, and the day on a timeline.
struct BriefContent: View {
    @ObservedObject var m: IslandModel
    let brief: Brief
    let inset: CGFloat

    static let lifetime: Double = 12

    var body: some View {
        let on = m.showContent
        let sun = rgb(1, 0.72, 0.35)
        let count = brief.meetings.count
        VStack(alignment: .leading, spacing: 0) {
            Wings(m: m) {
                HStack(spacing: 6) {
                    Image(systemName: "sun.horizon.fill").font(.system(size: 11, weight: .bold)).symbolRenderingMode(.multicolor)
                    Text("GOOD MORNING").kerning(0.6)
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(sun)
                .reveal(on, 0.02)
            } right: {
                Text(brief.shown.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .reveal(on, 0.05)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(count == 0 ? "No meetings today" : "\(count) meeting\(count == 1 ? "" : "s") today")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            .padding(.top, 8)
            .reveal(on, 0.07)

            DayTimeline(m: m, meetings: brief.meetings)
                .padding(.top, 14)
                .reveal(on, 0.11)

            Spacer(minLength: 10)

            HStack(spacing: 8) {
                Button { m.onOpenCalendar() } label: { Label("Calendar", systemImage: "calendar") }
                    .buttonStyle(IslandButtonStyle())
                Spacer()
                // Drains over the brief's lifetime, so you can see it'll tidy itself away.
                TimelineView(.animation) { tl in
                    let f = max(0, 1 - tl.date.timeIntervalSince(brief.shown) / Self.lifetime)
                    Circle().trim(from: 0, to: f).stroke(sun.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 14, height: 14)
                }
                Button { m.onBriefClose() } label: { Label("Got it", systemImage: "checkmark") }
                    .buttonStyle(IslandButtonStyle(fill: sun, ink: .black, prominent: true))
            }
            .reveal(on, 0.15)
        }
        .padding(.horizontal, inset)
        .padding(.bottom, 16)
    }

    private var detail: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        var parts: [String] = []
        if let first = brief.meetings.first {
            parts.append(first.start <= m.now ? "On now: \(first.title)" : "First up: \(first.title) at \(f.string(from: first.start))")
        } else {
            parts.append("Your calendar is clear")
        }
        if brief.reminders > 0 { parts.append("\(brief.reminders) reminder\(brief.reminders == 1 ? "" : "s") due") }
        return parts.joined(separator: "  ·  ")
    }
}

/// The rest of the day as a bar: a block per meeting, hour marks, and a glowing "now" line.
private struct DayTimeline: View {
    @ObservedObject var m: IslandModel
    let meetings: [Meeting]

    var body: some View {
        let cal = Calendar.current
        let now = m.now
        let startHour = cal.dateInterval(of: .hour, for: min(now, meetings.first?.start ?? now))!.start
        let lastEnd = meetings.map(\.end).max() ?? now
        var endHour = cal.dateInterval(of: .hour, for: lastEnd)!.end
        endHour = max(endHour, startHour.addingTimeInterval(8 * 3600))
        let span = endHour.timeIntervalSince(startHour)
        let hours = Int(span / 3600)
        let step = hours > 10 ? 3 : 2

        return VStack(spacing: 5) {
            GeometryReader { g in
                let x = { (d: Date) in g.size.width * CGFloat(max(0, min(1, d.timeIntervalSince(startHour) / span))) }
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.white.opacity(0.07))
                    ForEach(meetings) { mt in
                        let tint = mt.kind.tint(m.glow)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                            .opacity(mt.end <= now ? 0.35 : 1)
                            .frame(width: max(5, x(mt.end) - x(mt.start) - 2), height: 14)
                            .offset(x: x(mt.start) + 1)
                    }
                    Capsule().fill(.white).frame(width: 2, height: 22)
                        .shadow(color: .white.opacity(0.8), radius: 4)
                        .offset(x: x(now) - 1)
                }
            }
            .frame(height: 22)

            GeometryReader { g in
                ForEach(Array(stride(from: 0, through: hours, by: step)), id: \.self) { h in
                    let d = startHour.addingTimeInterval(Double(h) * 3600)
                    Text(d.formatted(.dateTime.hour(.twoDigits(amPM: .omitted))))
                        .font(.system(size: 9.5, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.4))
                        .fixedSize()
                        .position(x: min(max(8, g.size.width * CGFloat(h) / CGFloat(max(1, hours))), g.size.width - 8), y: 6)
                }
            }
            .frame(height: 12)
        }
    }
}
