import AppKit
import SwiftUI

/// 🎵 Now Playing, ambient: the album cover in the left wing and a little equaliser, tinted by the
/// cover, dancing in the right.
struct MusicContent: View {
    @ObservedObject var m: IslandModel
    let track: Track
    let inset: CGFloat

    var body: some View {
        Wings(m: m) {
            Artwork(image: track.artwork, size: 22, radius: 6).reveal(m.showContent)
        } right: {
            Equalizer(playing: track.playing, tint: track.tintColor, bars: 4, height: 14).reveal(m.showContent, 0.04)
        }
        .padding(.horizontal, inset)
    }
}

/// The player at the top of "Up next": cover, song, progress and the three transport buttons.
struct NowPlayingCard: View {
    static let height: CGFloat = 74

    @ObservedObject var m: IslandModel
    let track: Track

    var body: some View {
        let tint = track.tintColor
        HStack(spacing: 12) {
            Artwork(image: track.artwork, size: 56, radius: 12)
                .shadow(color: tint.opacity(0.35), radius: 10, y: 3)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(track.title)
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Equalizer(playing: track.playing, tint: tint, bars: 3, height: 10)
                }
                Text(track.artist.isEmpty ? track.app : track.artist)
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                progress(tint).padding(.top, 3)
            }
            HStack(spacing: 2) {
                transport("backward.fill", 12, .previous)
                transport(track.playing ? "pause.fill" : "play.fill", 17, .playPause)
                    .contentTransition(.symbolEffect(.replace))
                transport("forward.fill", 12, .next)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: Self.height)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(
            LinearGradient(colors: [tint.opacity(0.16), .white.opacity(0.04)], startPoint: .leading, endPoint: .trailing)))
    }

    private func progress(_ tint: Color) -> some View {
        let elapsed = track.elapsed(at: m.now)
        let frac = track.duration > 0 ? elapsed / track.duration : 0
        return HStack(spacing: 7) {
            Text(clock(elapsed))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.14))
                    Capsule().fill(tint).frame(width: max(4, g.size.width * frac))
                }
            }
            .frame(height: 4)
            Text(track.duration > 0 ? "-" + clock(track.duration - elapsed) : "")
        }
        .font(.system(size: 9.5, weight: .medium, design: .rounded).monospacedDigit())
        .foregroundStyle(.white.opacity(0.45))
    }

    private func transport(_ symbol: String, _ size: CGFloat, _ c: NowPlaying.Command) -> some View {
        Button { m.onMusic(c) } label: {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
    }

    private func clock(_ s: Double) -> String {
        let s = max(0, Int(s))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.82 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// The album cover, or a soft placeholder note when the player has none.
struct Artwork: View {
    let image: NSImage?
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [rgb(0.36, 0.3, 0.55), rgb(0.18, 0.16, 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note").font(.system(size: size * 0.45, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 0.5))
        .animation(.easeInOut(duration: 0.3), value: image != nil)
    }
}

/// Bars that bounce while the song plays and settle flat when it's paused. Each bar mixes two
/// waves at unrelated speeds, so the movement never visibly repeats.
struct Equalizer: View {
    let playing: Bool
    let tint: Color
    let bars: Int
    let height: CGFloat

    var body: some View {
        TimelineView(.animation(paused: !playing)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: height >= 14 ? 2.6 : 2.2) {
                ForEach(0..<bars, id: \.self) { i in
                    let d = Double(i)
                    let wave = abs(sin(t * (5.1 + d * 1.7) + d * 1.3)) * 0.6 + abs(sin(t * (2.3 + d * 0.9) + d * 2.1)) * 0.4
                    Capsule()
                        .fill(LinearGradient(colors: [tint, tint.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                        .frame(width: height >= 14 ? 3.2 : 2.6, height: playing ? height * (0.22 + 0.78 * wave) : height * 0.22)
                }
            }
            .frame(height: height)
        }
        .opacity(playing ? 1 : 0.55)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: playing)
    }
}

extension Track {
    var tintColor: Color { tint.map { Color(nsColor: $0) } ?? rgb(0.98, 0.42, 0.55) }

    /// Made-up songs with drawn covers for previews and screenshots, so docs never show anyone's library.
    static func demo(_ i: Int = 0, playing: Bool = true) -> Track {
        let songs: [(String, String, [NSColor])] = [
            ("Golden Hour Drive", "Neon Harbor", [NSColor(red: 1, green: 0.55, blue: 0.3, alpha: 1), NSColor(red: 0.85, green: 0.2, blue: 0.5, alpha: 1)]),
            ("Glass Ocean", "Lumen Fields", [NSColor(red: 0.2, green: 0.75, blue: 0.95, alpha: 1), NSColor(red: 0.25, green: 0.25, blue: 0.8, alpha: 1)]),
            ("Paper Planets", "The Quiet Arcade", [NSColor(red: 0.55, green: 0.9, blue: 0.45, alpha: 1), NSColor(red: 0.1, green: 0.5, blue: 0.45, alpha: 1)]),
        ]
        let (title, artist, colors) = songs[((i % songs.count) + songs.count) % songs.count]
        let art = demoCover(colors)
        return Track(player: .music, title: title, artist: artist, album: "Preview", duration: 214,
                     position: 71, positionAt: Date(), playing: playing, artwork: art, tint: NowPlaying.averageColor(art))
    }

    private static func demoCover(_ colors: [NSColor]) -> NSImage {
        NSImage(size: NSSize(width: 200, height: 200), flipped: false) { r in
            NSGradient(colors: colors)?.draw(in: r, angle: -55)
            // A sun setting over rolling hills.
            NSColor.white.withAlphaComponent(0.85).setFill()
            NSBezierPath(ovalIn: NSRect(x: 62, y: 74, width: 76, height: 76)).fill()
            for (k, a) in [(0, 0.35), (1, 0.55)] {
                let p = NSBezierPath()
                p.move(to: NSPoint(x: 0, y: 0))
                p.line(to: NSPoint(x: 0, y: 70 - k * 22))
                p.curve(to: NSPoint(x: 200, y: 62 - k * 18), controlPoint1: NSPoint(x: 70, y: 110 - k * 30),
                        controlPoint2: NSPoint(x: 130, y: 30 - k * 10))
                p.line(to: NSPoint(x: 200, y: 0))
                p.close()
                NSColor.black.withAlphaComponent(a).setFill()
                p.fill()
            }
            return true
        }
    }
}
