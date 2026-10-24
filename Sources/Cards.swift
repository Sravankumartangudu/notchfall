import SwiftUI

/// 🪞 Camera check: a live mirror inside the island, opened from the alert before you join.
struct MirrorContent: View {
    @ObservedObject var m: IslandModel
    let item: Meeting
    let inset: CGFloat

    var body: some View {
        let tint = item.kind.tint(m.glow)
        let on = m.showContent
        VStack(alignment: .leading, spacing: 0) {
            Wings(m: m) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.viewfinder").font(.system(size: 10, weight: .bold))
                    Text("CAMERA CHECK").kerning(0.6)
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .reveal(on, 0.02)
            } right: {
                CountdownLabel(item: item, now: m.now, tint: tint).reveal(on, 0.06)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.05))
                picture
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1)
            }
            .frame(height: 214)
            .overlay(alignment: .bottomLeading) {
                if m.fakeCamera || m.cameraState == .live {
                    HStack(spacing: 5) {
                        Image(systemName: "eye.slash.fill").font(.system(size: 9, weight: .bold))
                        Text("Only you can see this")
                    }
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 9).frame(height: 22)
                    .background(Capsule().fill(.black.opacity(0.45)))
                    .padding(10)
                }
            }
            .padding(.top, 8)
            .reveal(on, 0.06)

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Button { m.onMirror(false) } label: { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(IslandButtonStyle())
                Spacer()
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                Spacer()
                Button { m.onAction(.join, item) } label: {
                    Label("Join \(item.provider)", systemImage: "video.fill")
                }
                .buttonStyle(IslandButtonStyle(fill: tint, ink: .black, prominent: true))
            }
            .reveal(on, 0.12)
        }
        .padding(.horizontal, inset)
        .padding(.bottom, 16)
    }

    @ViewBuilder private var picture: some View {
        if m.fakeCamera {
            FakeCameraScene()
        } else {
            switch m.cameraState {
            case .live: CameraPreview(session: m.camera.session)
            case .denied:
                notice("video.slash.fill", "Camera access is off",
                       "Turn on Notchfall in System Settings → Privacy & Security → Camera.") {
                    Button("Open Camera settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(IslandButtonStyle())
                }
            case .noCamera:
                notice("video.slash", "No camera found", "Connect a camera, or quit another app that's using it.") { EmptyView() }
            case .off, .starting:
                VStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Starting the camera…").font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                }
            }
        }
    }

    private func notice<B: View>(_ symbol: String, _ title: String, _ text: String, @ViewBuilder button: () -> B) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(.white.opacity(0.6))
            Text(title).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
            Text(text).font(.system(size: 11.5, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center).frame(maxWidth: 340)
            button().padding(.top, 4)
        }
    }
}

/// 🎙 On air: mic and camera lights in the left wing, time left (or time on the call) in the right,
/// and the next meeting underneath when one starts straight after.
struct OnAirContent: View {
    @ObservedObject var m: IslandModel
    let air: OnAir
    let inset: CGFloat

    var body: some View {
        let red = rgb(1, 0.27, 0.3)
        let on = m.showContent
        VStack(spacing: 0) {
            Wings(m: m) {
                HStack(spacing: 7) {
                    LiveDot(color: red)
                    if air.muted {
                        // Muted with ⌃⌥M: the mic glyph is struck through, so it's obvious nobody hears you.
                        Image(systemName: "mic.slash.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(rgb(1, 0.6, 0.35))
                            .transition(.scale.combined(with: .opacity))
                    } else if air.mic {
                        Image(systemName: "mic.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(red)
                            .transition(.scale.combined(with: .opacity))
                    }
                    if air.camera {
                        Image(systemName: "video.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(rgb(0.3, 0.9, 0.45))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: air.mic)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: air.muted)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: air.camera)
                .reveal(on)
            } right: {
                timeText.reveal(on, 0.04)
            }

            if m.showsNext, let next = air.next {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.turn.down.right").font(.system(size: 9, weight: .bold))
                    Text("Next").fontWeight(.bold)
                    Text("\(next.title) at \(next.start.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))")
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(next.kind.tint(m.glow))
                .frame(height: 22)
                .reveal(on, 0.08)
            }
        }
        .padding(.horizontal, inset)
    }

    private var timeText: some View {
        let text: String
        var urgent = false
        if let mt = air.meeting {
            let left = mt.end.timeIntervalSince(m.now)
            urgent = left <= 300
            text = left <= 0 ? "over" : left < 60 ? "\(Int(left))s left" : "\(countdown(mt.end, now: m.now, short: true)) left"
        } else {
            let s = Int(m.now.timeIntervalSince(air.since))
            text = s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
        }
        return Text(text)
            .font(.system(size: 12.5, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(urgent ? rgb(1, 0.45, 0.35) : .white.opacity(0.85))
            .contentTransition(.numericText(countsDown: air.meeting != nil))
    }
}
