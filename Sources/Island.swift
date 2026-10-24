import AppKit
import SwiftUI

enum OverlayAction { case join, snooze, dismiss, next }

/// A little notice that pops out of the notch for a few seconds.
struct Toast: Equatable {
    enum Kind: Equatable {
        case charging(Int), headphones(String), mic(muted: Bool), stillMuted, shelf(Int)
        case downloaded(String), copied, note(symbol: String, text: String, tint: Color)
    }
    let kind: Kind
    let id = UUID()
}

/// ☀️ The morning brief: what today holds, shown once, the first time you sit down in the morning.
struct Brief: Equatable {
    var meetings: [Meeting]       // today's meetings that haven't ended yet
    var reminders: Int            // reminders due today
    var shown: Date
}

/// You're on a call: who's listening (mic, camera), how long is left, and what comes straight after.
struct OnAir: Equatable {
    var meeting: Meeting?     // the calendar meeting this call belongs to, if any
    var since: Date
    var mic: Bool
    var camera: Bool
    var muted = false         // the microphone itself is muted (⌃⌥M)
    var next: Meeting?        // a meeting that starts right as this one ends
}

/// Everything the island draws. The controller decides *what* to show; this model owns *how* it moves.
final class IslandModel: ObservableObject {
    enum Mode { case idle, bulge, peek, list, alert, mirror, onAir, music, toast, focus, brief, drop, notice, activity, hud, clips }

    @Published private(set) var mode: Mode = .idle
    @Published private(set) var visible = false
    @Published private(set) var showContent = false
    @Published var now = Date()
    @Published var alert: Meeting?
    @Published var peek: Meeting?
    @Published var agenda: [Meeting] = []
    @Published var rippleID = 0
    @Published var glow: Glow = .aurora
    @Published var onAir: OnAir?
    @Published var cameraState: CameraCheck.State = .off
    @Published var fakeCamera = false
    @Published var track: Track?
    @Published var toast: Toast?
    @Published var brief: Brief?
    @Published var focus: Meeting?     // the running focus or break stretch
    @Published var shelf: [URL] = []
    @Published var notice: Notice?
    @Published var activity: Activity?
    @Published var level: Level?
    @Published var clips: [Clip] = []
    @Published var demoDropTarget: String?   // previews: light up a drop zone without a real drag
    var draggingOut = false                  // a file is being dragged *off* the shelf

    var notch = CGSize(width: 190, height: 32)
    var hasNotch = true
    var lead: Double = 120
    var peekWindow: Double = 600
    var snoozeLabel: (Meeting) -> String = { _ in "Snooze" }
    var onAction: (OverlayAction, Meeting) -> Void = { _, _ in }
    var onJoin: (Meeting) -> Void = { _ in }
    var onMirror: (Bool) -> Void = { _ in }
    var onMusic: (NowPlaying.Command) -> Void = { _ in }
    var onBriefClose: () -> Void = {}
    var onOpenCalendar: () -> Void = {}
    var onShelfDrop: ([URL]) -> Void = { _ in }
    var onShelfRemove: (URL?) -> Void = { _ in }   // nil = clear the shelf
    var onNotice: (Notice, Bool) -> Void = { _, _ in } // true = its main button, false = dismissed
    var onClip: (Clip) -> Void = { _ in }
    let camera = CameraCheck()

    private var seq = 0

    struct Metrics { let width, height, top, bottom: CGFloat }

    /// `width` is the body without the flared ears; the drawn frame is `width + 2 * top`.
    func metrics(_ mode: Mode) -> Metrics {
        let w = notch.width, h = notch.height
        switch mode {
        case .idle: return Metrics(width: w, height: h, top: 0, bottom: 10)
        case .bulge: return Metrics(width: w + 22, height: h + 12, top: 8, bottom: 16)
        case .peek: return Metrics(width: w + 2 * 74, height: h, top: 6, bottom: 12)
        case .list:
            let rows = agenda.isEmpty ? 1.6 : Double(min(agendaRows, agenda.count))
            let player: CGFloat = track == nil ? 0 : NowPlayingCard.height + 8
            let shelfH: CGFloat = shelf.isEmpty ? 0 : ShelfStrip.height + 8
            return Metrics(width: max(470, w + 2 * 145), height: h + 12 + player + CGFloat(rows) * 46 + 14 + shelfH, top: 16, bottom: 32)
        case .alert:
            let people = (alert?.people.isEmpty ?? true) ? 0 : 18.0
            return Metrics(width: max(540, w + 2 * 172), height: h + 124 + people, top: 18, bottom: 38)
        case .mirror:
            return Metrics(width: max(540, w + 2 * 172), height: h + 8 + 214 + 14 + 32 + 16, top: 18, bottom: 38)
        case .onAir:
            return showsNext ? Metrics(width: w + 2 * 104, height: h + 28, top: 8, bottom: 16)
                             : Metrics(width: w + 2 * 92, height: h, top: 6, bottom: 12)
        case .music: return Metrics(width: w + 2 * 60, height: h, top: 6, bottom: 12)
        case .toast:
            switch toast?.kind {
            case .headphones: return Metrics(width: w + 2 * 112, height: h, top: 6, bottom: 12)
            case .stillMuted, .shelf, .copied: return Metrics(width: w + 2 * 104, height: h, top: 6, bottom: 12)
            case .downloaded, .note: return Metrics(width: w + 2 * 124, height: h, top: 6, bottom: 12)
            default: break
            }
            return Metrics(width: w + 2 * 92, height: h, top: 6, bottom: 12)
        case .focus: return Metrics(width: w + 2 * 78, height: h, top: 6, bottom: 12)
        case .brief: return Metrics(width: max(560, w + 2 * 182), height: h + 166, top: 18, bottom: 38)
        case .drop: return Metrics(width: max(520, w + 2 * 165), height: h + 10 + 76 + 16, top: 16, bottom: 32)
        case .notice:
            let long = (notice?.detail.count ?? 0) > 70 || (notice?.title.count ?? 0) > 44
            return Metrics(width: max(540, w + 2 * 172), height: h + 118 + (long ? 16 : 0), top: 18, bottom: 38)
        case .activity: return Metrics(width: w + 2 * 96, height: h, top: 6, bottom: 12)
        case .hud: return Metrics(width: w + 2 * 100, height: h, top: 6, bottom: 12)
        case .clips:
            let rows = clips.isEmpty ? 1.5 : Double(min(ClipsContent.rows, clips.count))
            return Metrics(width: max(500, w + 2 * 160), height: h + 8 + CGFloat(rows) * (ClipsContent.rowHeight + 2) + 18, top: 16, bottom: 32)
        }
    }

    /// "Up next" shows four rows, one fewer with the player on top and one fewer with the shelf below.
    var agendaRows: Int { 4 - (track == nil ? 0 : 1) - (shelf.isEmpty ? 0 : 1) }

    /// The "Next: …" line under the on-air wings, in the last 10 minutes of a back-to-back meeting.
    var showsNext: Bool {
        guard let a = onAir, a.next != nil, let m = a.meeting else { return false }
        return m.end.timeIntervalSince(now) <= 600
    }

    /// Big cards get a faint inner rim and a drop shadow; the slim wings states don't.
    var isCard: Bool { Self.big.contains(mode) }
    static let big: Set<Mode> = [.alert, .list, .mirror, .brief, .drop, .notice, .clips]

    var frameSize: CGSize {
        let m = metrics(mode)
        return CGSize(width: m.width + 2 * m.top, height: m.height)
    }

    /// Morph to a new state: fade the old content out, then spring the shape to its new size with a little
    /// overshoot, then let the new content blur in. Opening from the notch starts with a short "bulge" so it
    /// reads as something pushing its way out rather than a window appearing.
    func morph(to new: Mode) {
        guard new != mode || (new != .idle && !visible) else { return }
        seq += 1
        let token = seq
        withAnimation(.easeIn(duration: 0.1)) { showContent = false }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) { [self] in
            guard token == seq else { return }
            if new == .idle {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    mode = .idle
                } completion: { [self] in
                    if token == seq { visible = false }
                }
                return
            }
            let fromNotch = mode == .idle || !visible
            visible = true
            let open = { [self] in
                guard token == seq else { return }
                let big = Self.big.contains(new)
                withAnimation(big ? .spring(response: 0.52, dampingFraction: 0.64) : .spring(response: 0.42, dampingFraction: 0.72)) {
                    mode = new
                }
                if big { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
                DispatchQueue.main.asyncAfter(deadline: .now() + (big ? 0.14 : 0.1)) { [self] in
                    if token == seq { showContent = true }
                }
            }
            if fromNotch && Self.big.contains(new) {
                withAnimation(.easeOut(duration: 0.13)) { mode = .bulge }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.13, execute: open)
            } else {
                open()
            }
        }
    }
}

// MARK: - View

struct IslandView: View {
    @ObservedObject var m: IslandModel

    var body: some View {
        let met = m.metrics(m.mode)
        let shape = NotchShape(top: met.top, bottom: met.bottom)
        let size = CGSize(width: met.width + 2 * met.top, height: met.height)

        ZStack(alignment: .top) {
            if let a = m.alert, m.mode == .alert || m.mode == .mirror {
                GlowRim(shape: shape, colors: m.glow.colors, urgency: urgency(a, lead: m.lead))
                    .frame(width: size.width, height: size.height)
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
            } else if m.mode == .brief {
                // A slow, gentle glow: good morning, not an alarm.
                GlowRim(shape: shape, colors: [rgb(1, 0.72, 0.35), rgb(1, 0.45, 0.45), rgb(0.95, 0.85, 0.5), rgb(1, 0.55, 0.3)], urgency: 0)
                    .frame(width: size.width, height: size.height)
                    .opacity(0.55)
                    .transition(.opacity.animation(.easeInOut(duration: 0.6)))
            } else if let n = m.notice, m.mode == .notice {
                // The rim takes the colour of whatever is asking for attention.
                GlowRim(shape: shape, colors: [n.tint, n.tint.opacity(0.55), .white.opacity(0.5), n.tint.opacity(0.8)], urgency: n.sticky ? 0.4 : 0)
                    .frame(width: size.width, height: size.height)
                    .opacity(0.55)
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
            } else if let p = m.peek, m.mode == .peek, urgency(p, lead: 60) > 0 {
                GlowRim(shape: shape, colors: m.glow.colors, urgency: urgency(p, lead: 60))
                    .frame(width: size.width, height: size.height)
                    .opacity(0.6)
                    .transition(.opacity.animation(.easeInOut(duration: 0.6)))
            } else if let end = m.onAir?.meeting?.end, m.mode == .onAir, end.timeIntervalSince(m.now) <= 300 {
                // Last five minutes of the call: the rim wakes up and warms as the end gets close.
                GlowRim(shape: shape, colors: m.glow.colors, urgency: max(0.2, 1 - end.timeIntervalSince(m.now) / 300))
                    .frame(width: size.width, height: size.height)
                    .opacity(0.6)
                    .transition(.opacity.animation(.easeInOut(duration: 0.6)))
            }
            if m.rippleID > 0, m.mode == .alert {
                Ripple(shape: shape, color: m.alert.map { $0.kind.tint(m.glow) } ?? .white)
                    .frame(width: size.width, height: size.height)
                    .id(m.rippleID)
            }

            ZStack(alignment: .top) {
                shape.fill(.black)
                // Faint inner rim so the card has depth against dark wallpapers.
                shape.stroke(.white.opacity(m.isCard ? 0.07 : 0), lineWidth: 1)
                content(met)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .shadow(color: .black.opacity(m.isCard ? 0.55 : 0), radius: 22, y: 10)
        }
        .opacity(m.visible ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private func content(_ met: IslandModel.Metrics) -> some View {
        switch m.mode {
        case .alert:
            if let a = m.alert { AlertContent(m: m, item: a, inset: met.top + 20) }
        case .list: AgendaContent(m: m, inset: met.top + 16)
        case .peek:
            if let p = m.peek { PeekContent(m: m, item: p, inset: met.top + 10) }
        case .mirror:
            if let a = m.alert { MirrorContent(m: m, item: a, inset: met.top + 20) }
        case .onAir:
            if let a = m.onAir { OnAirContent(m: m, air: a, inset: met.top + 10) }
        case .music:
            if let t = m.track { MusicContent(m: m, track: t, inset: met.top + 10) }
        case .toast:
            if let t = m.toast { ToastContent(m: m, toast: t, inset: met.top + 10) }
        case .focus:
            if let f = m.focus { FocusContent(m: m, item: f, inset: met.top + 10) }
        case .brief:
            if let b = m.brief { BriefContent(m: m, brief: b, inset: met.top + 20) }
        case .drop: DropContent(m: m, inset: met.top + 16)
        case .notice:
            if let n = m.notice { NoticeContent(m: m, notice: n, inset: met.top + 20) }
        case .activity:
            if let a = m.activity { ActivityContent(m: m, activity: a, inset: met.top + 10) }
        case .hud:
            if let l = m.level { LevelContent(m: m, level: l, inset: met.top + 10) }
        case .clips: ClipsContent(m: m, inset: met.top + 16)
        case .idle, .bulge: EmptyView()
        }
    }
}

/// 0 while plenty of time is left, rising to 1 at the start time (and staying 1 once live).
func urgency(_ item: Meeting, lead: Double, now: Date = Date()) -> Double {
    let left = item.start.timeIntervalSince(now)
    if left <= 0 { return 1 }
    return max(0, min(1, 1 - left / max(lead, 1)))
}

func countdown(_ start: Date, now: Date, short: Bool = false) -> String {
    let s = Int(ceil(start.timeIntervalSince(now)))
    if s <= 0 { return "now" }
    if short && s >= 60 { return s >= 3600 ? "\(s / 3600)h" : "\(Int(ceil(Double(s) / 60)))m" }
    if s < 3600 { return String(format: "%d:%02d", s / 60, s % 60) }
    return "\(s / 3600)h \(s % 3600 / 60)m"
}

struct Reveal: ViewModifier {
    let on: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(on ? 1 : 0)
            .blur(radius: on ? 0 : 8)
            .scaleEffect(on ? 1 : 0.9, anchor: .top)
            .offset(y: on ? 0 : -8)
            .animation(on ? .spring(response: 0.48, dampingFraction: 0.76).delay(delay) : .easeIn(duration: 0.09), value: on)
    }
}

extension View {
    func reveal(_ on: Bool, _ delay: Double = 0) -> some View { modifier(Reveal(on: on, delay: delay)) }
}

/// The two "wings" either side of the camera housing. Nothing is drawn in the middle, where the notch is.
struct Wings<L: View, R: View>: View {
    let m: IslandModel
    @ViewBuilder let left: L
    @ViewBuilder let right: R

    var body: some View {
        HStack(spacing: 0) {
            left.frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: m.hasNotch ? m.notch.width + 12 : 24)
            right.frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: m.notch.height)
    }
}

struct LiveDot: View {
    let color: Color
    @State private var pulse = false
    var body: some View {
        Circle().fill(color).frame(width: 7, height: 7)
            .background(Circle().fill(color.opacity(0.5)).scaleEffect(pulse ? 2.4 : 1).opacity(pulse ? 0 : 1))
            .onAppear { withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { pulse = true } }
    }
}

/// Rolling digits ("in 1:58"), or a pulsing LIVE / DUE / TIME'S UP tag once the moment arrives.
struct CountdownLabel: View {
    let item: Meeting
    let now: Date
    let tint: Color

    var body: some View {
        if item.start > now {
            HStack(spacing: 4) {
                Text("in").foregroundStyle(.white.opacity(0.45))
                Text(countdown(item.start, now: now))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText(countsDown: true))
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
        } else {
            let red = rgb(1, 0.27, 0.3)
            HStack(spacing: 6) {
                LiveDot(color: red)
                Text(item.kind == .meeting ? "LIVE" : item.kind == .timer ? "TIME'S UP" : item.kind == .leave ? "LEAVE NOW"
                     : item.kind == .focus ? (item.isBreak ? "BREAK'S OVER" : "DONE") : "DUE NOW")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .kerning(0.8)
                    .foregroundStyle(red)
            }
        }
    }
}

private struct AlertContent: View {
    @ObservedObject var m: IslandModel
    let item: Meeting
    let inset: CGFloat

    var body: some View {
        let tint = item.kind.tint(m.glow)
        let on = m.showContent
        VStack(alignment: .leading, spacing: 0) {
            Wings(m: m) {
                HStack(spacing: 6) {
                    Image(systemName: item.symbol).font(.system(size: 10, weight: .bold))
                    Text(item.provider.uppercased()).kerning(0.6)
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .reveal(on, 0.02)
            } right: {
                CountdownLabel(item: item, now: m.now, tint: tint).reveal(on, 0.06)
            }

            HStack(alignment: .center, spacing: 14) {
                CountdownBadge(symbol: item.symbol, tint: tint,
                               progress: 1 - urgency(item, lead: m.lead, now: m.now), live: item.start <= m.now)
                    .reveal(on, 0.04)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .overlay(Shimmer(active: item.start <= m.now).mask(
                            Text(item.title).font(.system(size: 17, weight: .semibold, design: .rounded)).lineLimit(2)))
                    Text(item.subtitle)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                    if !item.people.isEmpty {
                        AvatarStack(names: item.people).padding(.top, 3)
                    }
                }
                .reveal(on, 0.08)
                Spacer(minLength: 0)
            }
            .padding(.top, 8)

            Spacer(minLength: 10)

            HStack(spacing: 8) {
                Button { m.onAction(.dismiss, item) } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(IslandButtonStyle())
                .help("Dismiss")
                Button(m.snoozeLabel(item)) { m.onAction(.snooze, item) }
                    .buttonStyle(IslandButtonStyle())
                Spacer()
                if item.kind == .meeting, item.link != nil {
                    Button { m.onMirror(true) } label: {
                        Image(systemName: "camera.viewfinder").font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(IslandButtonStyle())
                    .help("Camera check: see yourself before you join")
                }
                if item.kind == .focus {
                    Button { m.onAction(.next, item) } label: {
                        Label(item.isBreak ? "Back to focus" : "Start break",
                              systemImage: item.isBreak ? "brain.head.profile" : "cup.and.saucer.fill")
                    }
                    .buttonStyle(IslandButtonStyle(fill: tint, ink: .black, prominent: true))
                } else if item.link != nil {
                    Button { m.onAction(.join, item) } label: {
                        Label(item.kind == .meeting ? "Join \(item.provider)" : item.kind == .leave ? "Directions" : "Open link",
                              systemImage: item.kind == .leave ? "map.fill" : "video.fill")
                    }
                    .buttonStyle(IslandButtonStyle(fill: tint, ink: .black, prominent: true))
                } else {
                    Button { m.onAction(.dismiss, item) } label: { Label("Done", systemImage: "checkmark") }
                        .buttonStyle(IslandButtonStyle(fill: tint, ink: .black, prominent: true))
                }
            }
            .reveal(on, 0.13)
        }
        .padding(.horizontal, inset)
        .padding(.bottom, 16)
    }
}

/// A soft highlight that sweeps across the title once the meeting is live.
private struct Shimmer: View {
    let active: Bool
    var body: some View {
        if active {
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4
                GeometryReader { g in
                    LinearGradient(colors: [.clear, .white.opacity(0.85), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: g.size.width * 0.35)
                        .offset(x: -g.size.width * 0.4 + t * g.size.width * 1.8)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

private struct PeekContent: View {
    @ObservedObject var m: IslandModel
    let item: Meeting
    let inset: CGFloat

    var body: some View {
        let tint = item.kind.tint(m.glow)
        Wings(m: m) {
            CountdownBadge(symbol: item.symbol, tint: tint,
                           progress: 1 - urgency(item, lead: m.peekWindow, now: m.now), live: item.start <= m.now, size: 22)
                .reveal(m.showContent)
        } right: {
            Text(countdown(item.start, now: m.now, short: true))
                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(tint)
                .contentTransition(.numericText(countsDown: true))
                .reveal(m.showContent, 0.04)
        }
        .padding(.horizontal, inset)
    }
}

private struct AgendaContent: View {
    @ObservedObject var m: IslandModel
    let inset: CGFloat

    var body: some View {
        let on = m.showContent
        VStack(spacing: 0) {
            Wings(m: m) {
                Text(m.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .reveal(on)
            } right: {
                Text(m.now.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                    .reveal(on, 0.03)
            }
            .padding(.horizontal, 6)

            if let t = m.track {
                NowPlayingCard(m: m, track: t).padding(.top, 8).reveal(on, 0.04)
            }

            if m.agenda.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(m.glow.accent)
                        .symbolEffect(.pulse, options: .repeating)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clear skies").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        Text("Nothing in the next 18 hours.").font(.system(size: 11.5, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                }
                .padding(.top, 14)
                .padding(.horizontal, 6)
                .reveal(on, 0.06)
            } else {
                VStack(spacing: 2) {
                    ForEach(Array(m.agenda.prefix(m.agendaRows).enumerated()), id: \.element.id) { i, item in
                        AgendaRow(m: m, item: item).reveal(on, 0.05 + Double(i) * 0.045)
                    }
                }
                .padding(.top, 8)
            }
            Spacer(minLength: 0)
            if !m.shelf.isEmpty {
                ShelfStrip(m: m).padding(.bottom, 12).reveal(on, 0.2)
            }
        }
        .padding(.horizontal, inset - 6)
    }
}

private struct AgendaRow: View {
    @ObservedObject var m: IslandModel
    let item: Meeting
    @State private var hover = false

    var body: some View {
        let tint = item.kind.tint(m.glow)
        HStack(spacing: 11) {
            Image(systemName: item.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(item.start.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))  ·  \(item.provider)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
            }
            Spacer(minLength: 6)
            Text(item.start <= m.now ? "now" : "in \(countdown(item.start, now: m.now, short: true))")
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(item.start <= m.now ? rgb(1, 0.3, 0.35) : tint)
            if item.link != nil {
                Button { m.onJoin(item) } label: {
                    Image(systemName: item.kind == .leave ? "map.fill" : "video.fill").font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(IslandButtonStyle(fill: tint, ink: .black))
                .help(item.kind == .leave ? "Directions in Maps" : "Join \(item.provider)")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(hover ? 0.07 : 0)))
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
    }
}

// MARK: - Window

final class IslandPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // Above the menu bar so the island can grow out of the notch over it.
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Buttons must work on the first click even though the panel never activates the app.
final class FirstClickHostingView<V: View>: NSHostingView<V> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Places the island over the notch, picks the state to show, and makes the window click-through
/// everywhere except the island itself.
final class IslandController {
    let model = IslandModel()
    private let panel = IslandPanel()
    private static let canvas = CGSize(width: 820, height: 360)
    private var center = CGPoint.zero      // top-centre of the notch, in screen coordinates
    private var mouseTimer: Timer?
    private var enteredAt: Date?
    private var leftAt: Date?
    private(set) var hovering = false

    var hoverEnabled = true
    var peekEnabled = true
    var catchDrops = true
    private(set) var dropping = false
    private var demoDrop = false
    private let dragBoard = NSPasteboard(name: .drag)
    private lazy var dragBase = dragBoard.changeCount
    private var dropCloseAt: Date?
    var screenChoice = "notch"

    var isShowingAlert: Bool { model.alert != nil }
    private(set) var mirrorOpen = false
    var windowNumber: Int { panel.windowNumber }

    init() {
        let host = FirstClickHostingView(rootView: IslandView(m: model))
        host.sizingOptions = []
        panel.contentView = host
        place()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.place() }
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.trackMouse() }
        RunLoop.main.add(t, forMode: .common)
        mouseTimer = t
    }

    var screen: NSScreen? {
        let notched = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
        return (screenChoice == "notch" ? notched : nil) ?? NSScreen.screens.first
    }

    func place() {
        guard let s = screen else { return }
        if s.safeAreaInsets.top > 0, let l = s.auxiliaryTopLeftArea, let r = s.auxiliaryTopRightArea {
            let w = s.frame.width - l.width - r.width
            model.notch = CGSize(width: w, height: s.safeAreaInsets.top)
            model.hasNotch = true
            center = CGPoint(x: s.frame.minX + l.width + w / 2, y: s.frame.maxY)
        } else {
            // No notch: hang a virtual one from the middle of the menu bar.
            let bar = max(24, s.frame.maxY - s.visibleFrame.maxY)
            model.notch = CGSize(width: 150, height: bar)
            model.hasNotch = false
            center = CGPoint(x: s.frame.midX, y: s.frame.maxY)
        }
        let c = Self.canvas
        panel.setFrame(NSRect(x: center.x - c.width / 2, y: center.y - c.height, width: c.width, height: c.height), display: true)
        panel.orderFrontRegardless()
    }

    func present(_ m: Meeting) {
        model.alert = m
        resolve()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.model.rippleID += 1 }
    }

    func closeAlert() {
        setMirror(false)
        model.alert = nil
        resolve()
    }

    /// Opens or closes the camera check in place of the alert. The camera only runs while it's open.
    func setMirror(_ open: Bool) {
        guard open != mirrorOpen, !open || model.alert != nil else { return }
        mirrorOpen = open
        if open {
            if !model.fakeCamera {
                model.camera.onState = { [weak self] s in self?.model.cameraState = s }
                model.camera.start()
            }
        } else {
            model.camera.stop()
            model.cameraState = .off
        }
        resolve()
    }

    private var listPreview = false
    /// The clipboard history, opened with ⌃⌥V.
    var clipsOpen = false

    /// Opens "Up next" as if hovered, for the preview menu and screenshots.
    func showListPreview(for seconds: Double, done: @escaping () -> Void) {
        listPreview = true
        resolve()
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.listPreview = false
            self?.resolve()
            done()
        }
    }

    /// Opens the drop zones as if a file were being dragged in, for the preview menu and screenshots.
    func showDropPreview(for seconds: Double, target: String?) {
        demoDrop = true
        model.demoDropTarget = nil
        resolve()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            if self?.demoDrop == true { self?.model.demoDropTarget = target }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.demoDrop = false
            self?.model.demoDropTarget = nil
            self?.resolve()
        }
    }

    func resolve() {
        if model.alert != nil { model.morph(to: mirrorOpen ? .mirror : .alert) }
        else if dropping || demoDrop { model.morph(to: .drop) }
        else if clipsOpen { model.morph(to: .clips) }
        else if model.notice != nil { model.morph(to: .notice) }
        else if model.brief != nil { model.morph(to: .brief) }
        else if hovering || listPreview { model.morph(to: .list) }
        else if model.level != nil { model.morph(to: .hud) }
        else if model.toast != nil { model.morph(to: .toast) }
        else if model.onAir != nil { model.morph(to: .onAir) }
        else if peekEnabled, model.peek != nil { model.morph(to: .peek) }
        else if model.activity != nil { model.morph(to: .activity) }
        else if model.focus != nil { model.morph(to: .focus) }
        else if model.track?.playing == true { model.morph(to: .music) }
        else { model.morph(to: .idle) }
    }

    /// The part of the screen the island currently covers.
    private var hotRect: CGRect {
        let size: CGSize
        if model.mode == .idle {
            guard hoverEnabled, model.hasNotch else { return .zero }
            size = model.notch
        } else {
            size = model.frameSize
        }
        let r = CGRect(x: center.x - size.width / 2, y: center.y - size.height, width: size.width, height: size.height)
        return hovering ? r.insetBy(dx: -8, dy: -10) : r
    }

    /// A file drag from Finder (or anywhere) shows up as a new drag pasteboard holding file URLs while the
    /// button is down. Only its types are looked at, never its contents. Bringing the drag up to the notch
    /// opens the drop zones; letting go anywhere closes them again.
    private func trackDrop() {
        let down = NSEvent.pressedMouseButtons & 1 != 0
        if !down {
            dragBase = dragBoard.changeCount
            model.draggingOut = false
            // Give the drop itself a moment to land before the zones fold away.
            if dropping {
                if dropCloseAt == nil { dropCloseAt = Date().addingTimeInterval(0.35) }
                if Date() >= dropCloseAt! { dropping = false; dropCloseAt = nil; resolve() }
            }
            return
        }
        dropCloseAt = nil
        guard catchDrops, model.alert == nil, !model.draggingOut, dragBoard.changeCount != dragBase,
              dragBoard.types?.contains(.fileURL) == true else { return }
        let p = NSEvent.mouseLocation
        let d = model.metrics(.drop), w = d.width + 2 * d.top
        let zone = dropping
            ? CGRect(x: center.x - w / 2, y: center.y - d.height, width: w, height: d.height).insetBy(dx: -50, dy: -50)
            : CGRect(x: center.x - 230, y: center.y - 70, width: 460, height: 70)
        let near = zone.contains(p)
        if near != dropping { dropping = near; resolve() }
    }

    private func trackMouse() {
        trackDrop()
        let inside = hotRect.contains(NSEvent.mouseLocation)
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }

        let canHover = hoverEnabled && (model.hasNotch || model.mode != .idle)
        if inside && canHover {
            leftAt = nil
            if !hovering {
                if enteredAt == nil { enteredAt = Date() }
                if Date().timeIntervalSince(enteredAt!) > 0.12 {
                    hovering = true
                    resolve()
                }
            }
        } else {
            enteredAt = nil
            if hovering {
                if leftAt == nil { leftAt = Date() }
                if Date().timeIntervalSince(leftAt!) > 0.3 {
                    hovering = false
                    leftAt = nil
                    resolve()
                }
            }
        }
    }
}
