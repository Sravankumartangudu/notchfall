import SwiftUI

/// Glow palettes for the island's rim. The island itself is always pure black so it melts into the notch.
enum Glow: String, CaseIterable {
    case aurora, neon, ember, ice, mono

    var label: String {
        switch self {
        case .aurora: return "Aurora (multicolour)"
        case .neon: return "Neon (green and cyan)"
        case .ember: return "Ember (orange and red)"
        case .ice: return "Ice (blue and white)"
        case .mono: return "Mono (white)"
        }
    }

    var colors: [Color] {
        switch self {
        case .aurora: return [rgb(0.25, 0.55, 1.0), rgb(0.70, 0.35, 1.0), rgb(1.0, 0.35, 0.65), rgb(1.0, 0.62, 0.25), rgb(0.25, 0.85, 1.0)]
        case .neon: return [rgb(0.2, 1.0, 0.55), rgb(0.15, 0.85, 1.0), rgb(0.55, 1.0, 0.3), rgb(0.1, 0.65, 1.0)]
        case .ember: return [rgb(1.0, 0.35, 0.15), rgb(1.0, 0.68, 0.2), rgb(1.0, 0.2, 0.35), rgb(1.0, 0.85, 0.4)]
        case .ice: return [rgb(0.6, 0.85, 1.0), rgb(1, 1, 1), rgb(0.3, 0.6, 1.0), rgb(0.75, 0.95, 1.0)]
        case .mono: return [rgb(1, 1, 1), rgb(0.55, 0.55, 0.6), rgb(0.9, 0.9, 0.95), rgb(0.4, 0.4, 0.45)]
        }
    }

    /// Accent for the Join button, countdown digits and progress rings.
    var accent: Color {
        switch self {
        case .aurora: return rgb(0.35, 0.65, 1.0)
        case .neon: return rgb(0.2, 1.0, 0.55)
        case .ember: return rgb(1.0, 0.55, 0.2)
        case .ice: return rgb(0.55, 0.82, 1.0)
        case .mono: return rgb(0.92, 0.92, 0.95)
        }
    }
}

func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }

extension Meeting.Kind {
    /// Reminders and timers get their own tint so they read differently from meetings at a glance.
    func tint(_ glow: Glow) -> Color {
        switch self {
        case .meeting: return glow.accent
        case .reminder: return rgb(1.0, 0.72, 0.25)
        case .timer: return rgb(0.35, 0.95, 0.75)
        }
    }
}

/// The island outline: flat along the top edge of the screen, with concave "ears" that flare into the
/// menu bar, straight sides and rounded bottom corners. Both radii animate, so the shape morphs smoothly
/// from the hardware notch into a full card and back.
struct NotchShape: Shape {
    var top: CGFloat
    var bottom: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(top, bottom) }
        set { top = newValue.first; bottom = newValue.second }
    }

    func path(in r: CGRect) -> Path {
        let t = max(0, min(top, r.width / 4, r.height / 2))
        let b = max(0, min(bottom, r.height - t, (r.width - 2 * t) / 2))
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX + t, y: r.minY + t), control: CGPoint(x: r.minX + t, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + t, y: r.maxY - b))
        // Cubic corners with Apple's "continuous" feel rather than a plain circular arc.
        p.addCurve(to: CGPoint(x: r.minX + t + b, y: r.maxY),
                   control1: CGPoint(x: r.minX + t, y: r.maxY - b * 0.45),
                   control2: CGPoint(x: r.minX + t + b * 0.45, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - t - b, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.maxX - t, y: r.maxY - b),
                   control1: CGPoint(x: r.maxX - t - b * 0.45, y: r.maxY),
                   control2: CGPoint(x: r.maxX - t, y: r.maxY - b * 0.45))
        p.addLine(to: CGPoint(x: r.maxX - t, y: r.minY + t))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.maxX - t, y: r.minY))
        p.closeSubpath()
        return p
    }
}

/// A slowly turning, breathing gradient light around the island's edge (drawn behind the black body so
/// only the outer half shows). `urgency` 0…1 speeds it up and warms it as the start time gets close.
struct GlowRim: View {
    let shape: NotchShape
    let colors: [Color]
    let urgency: Double

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let speed = 40 + urgency * 140
            let breathe = 0.72 + 0.28 * sin(t * (1.6 + urgency * 4))
            let palette = urgency > 0.85 ? [rgb(1, 0.25, 0.3), rgb(1, 0.55, 0.2), rgb(1, 0.2, 0.5), rgb(1, 0.4, 0.3)] : colors
            let gradient = AngularGradient(colors: palette + [palette[0]], center: .center,
                                           angle: .degrees((t * speed).truncatingRemainder(dividingBy: 360)))
            ZStack {
                shape.stroke(gradient, lineWidth: 18).blur(radius: 22).opacity(0.55 * breathe)
                shape.stroke(gradient, lineWidth: 6).blur(radius: 6).opacity(0.9 * breathe)
                shape.stroke(gradient, lineWidth: 2)
            }
        }
        .allowsHitTesting(false)
    }
}

/// A one-shot shockwave that rings out from the island when an alert lands.
struct Ripple: View {
    let shape: NotchShape
    let color: Color
    @State private var go = false

    var body: some View {
        shape
            .stroke(color, lineWidth: go ? 1 : 5)
            .scaleEffect(go ? 1.32 : 1, anchor: .top)
            .opacity(go ? 0 : 0.9)
            .blur(radius: go ? 6 : 1)
            .onAppear { withAnimation(.easeOut(duration: 1.1)) { go = true } }
            .allowsHitTesting(false)
    }
}

/// App-icon-style badge: the item's symbol inside a ring that drains as the start time approaches.
struct CountdownBadge: View {
    let symbol: String
    let tint: Color
    let progress: Double   // 1 = full lead time left, 0 = starting now
    let live: Bool
    var size: CGFloat = 54

    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.16))
            Circle().stroke(.white.opacity(0.08), lineWidth: 3.5)
            Circle()
                // Once it's live the ring closes into a full circle rather than draining to a lone dot.
                .trim(from: 0, to: live ? 1 : max(0.001, progress))
                .stroke(tint, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.8), radius: 4)
                .animation(.linear(duration: 1), value: progress)
            Image(systemName: symbol)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(tint)
                .symbolEffect(.pulse, options: .repeating, isActive: live)
                .symbolEffect(.bounce, value: live)
        }
        .frame(width: size, height: size)
    }
}

/// Overlapping initials for the meeting's attendees.
struct AvatarStack: View {
    let names: [String]
    var max = 5

    var body: some View {
        HStack(spacing: -5) {
            ForEach(Array(names.prefix(max).enumerated()), id: \.offset) { _, name in
                Text(initials(name))
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(hue(name).gradient))
                    .overlay(Circle().stroke(.black, lineWidth: 2))
            }
            if names.count > max {
                Text("+\(names.count - max)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 28, height: 24)
                    .background(Capsule().fill(.white.opacity(0.14)))
                    .overlay(Capsule().stroke(.black, lineWidth: 2))
            }
        }
    }

    private func initials(_ s: String) -> String {
        let parts = s.split(whereSeparator: { $0 == " " || $0 == "." || $0 == "@" }).prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private func hue(_ s: String) -> Color {
        let h = s.unicodeScalars.reduce(UInt32(5381)) { ($0 &* 33) &+ $1.value }
        return Color(hue: Double(h % 360) / 360, saturation: 0.55, brightness: 0.85)
    }
}

/// Capsule buttons that brighten on hover and squish when pressed.
struct IslandButtonStyle: ButtonStyle {
    var fill: Color = .white.opacity(0.12)
    var ink: Color = .white
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        Hovering { hovering in
            configuration.label
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(
                    Capsule().fill(fill)
                        .brightness(hovering ? 0.12 : 0)
                        .shadow(color: prominent ? fill.opacity(0.6) : .clear, radius: hovering ? 12 : 7)
                )
                .scaleEffect(configuration.isPressed ? 0.93 : (hovering ? 1.04 : 1))
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
        }
    }
}

struct Hovering<Content: View>: View {
    @ViewBuilder let content: (Bool) -> Content
    @State private var on = false
    var body: some View { content(on).onHover { on = $0 } }
}
