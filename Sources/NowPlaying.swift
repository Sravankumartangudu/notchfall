import AppKit

/// The song playing in Apple Music or Spotify.
struct Track: Equatable {
    enum Player: String { case music = "com.apple.Music", spotify = "com.spotify.client" }

    var player: Player
    var title: String
    var artist: String
    var album: String
    var duration: Double          // seconds; 0 if unknown
    var position: Double          // seconds, as of `positionAt`
    var positionAt: Date
    var playing: Bool
    var artwork: NSImage?
    var tint: NSColor?

    var key: String { "\(player.rawValue)|\(title)|\(artist)|\(album)" }
    var app: String { player == .music ? "Music" : "Spotify" }

    func elapsed(at now: Date) -> Double {
        let p = position + (playing ? now.timeIntervalSince(positionAt) : 0)
        return duration > 0 ? min(max(0, p), duration) : max(0, p)
    }

    /// Same song, same state, and the position is where the clock says it should be (so a fresh read
    /// of a song that's simply playing on doesn't count as a change, but a seek does).
    static func == (a: Track, b: Track) -> Bool {
        a.key == b.key && a.playing == b.playing && abs(a.elapsed(at: b.positionAt) - b.position) < 1.5
            && a.duration == b.duration && (a.artwork == nil) == (b.artwork == nil)
    }
}

/// Reads Apple Music and Spotify with AppleScript (the same way Shortcuts and Alfred do) instead of
/// the private MediaRemote framework. It only ever talks to a player that's already running, so it
/// never launches one, and it listens for their "track changed" broadcasts to update instantly.
final class NowPlaying {
    enum Command { case playPause, next, previous, pause, play }

    var onChange: (Track?) -> Void = { _ in }
    private(set) var track: Track?
    var enabled = true { didSet { if !enabled { set(nil) } else { poll() } } }

    private let queue = DispatchQueue(label: "notchfall.nowplaying")
    private var timer: Timer?
    private var busy = false
    private var artKey = ""
    private var art: (NSImage, NSColor)?

    func start() {
        let dnc = DistributedNotificationCenter.default()
        for name in ["com.apple.Music.playerInfo", "com.spotify.client.PlaybackStateChanged"] {
            dnc.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                // The broadcast carries no position or artwork, so read the player properly.
                self?.poll()
            }
        }
        let t = Timer(timeInterval: 3, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        poll()
    }

    private func running(_ p: Track.Player) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: p.rawValue).isEmpty
    }

    func poll() {
        guard enabled, !busy else { return }
        // Prefer whichever app is playing; Music first when both are.
        let players = [Track.Player.music, .spotify].filter(running)
        guard !players.isEmpty else { return set(nil) }
        busy = true
        queue.async { [weak self] in
            guard let self else { return }
            let tracks = players.compactMap { self.read($0) }
            let best = tracks.first { $0.playing } ?? tracks.first
            DispatchQueue.main.async {
                self.busy = false
                self.set(best)
            }
        }
    }

    private func set(_ t: Track?) {
        var t = t
        if let cur = t, let a = art, artKey == cur.key { t?.artwork = a.0; t?.tint = a.1 }
        guard t != track else { return }
        track = t
        onChange(t)
        if let cur = t, cur.key != artKey { loadArtwork(cur) }
    }

    func send(_ c: Command) {
        guard let p = track?.player, running(p) else { return }
        let verb: String
        switch c {
        case .playPause: verb = "playpause"
        case .next: verb = "next track"
        case .previous: verb = "previous track"
        case .pause: verb = "pause"
        case .play: verb = "play"
        }
        // Show the new state straight away instead of waiting for the next read.
        if var t = track, c != .next, c != .previous {
            t.position = t.elapsed(at: Date())
            t.positionAt = Date()
            t.playing = c == .play || (c == .playPause && !t.playing)
            track = t
            onChange(t)
        }
        queue.async { [weak self] in
            _ = Self.run("tell application id \"\(p.rawValue)\" to \(verb)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self?.poll() }
        }
    }

    // MARK: - AppleScript (background queue)

    private static func run(_ source: String) -> NSAppleEventDescriptor? {
        var err: NSDictionary?
        let r = NSAppleScript(source: source)?.executeAndReturnError(&err)
        return err == nil ? r : nil
    }

    private func read(_ p: Track.Player) -> Track? {
        let script = """
        tell application id "\(p.rawValue)"
            set st to (player state as text)
            if st is "stopped" then return {st}
            set t to current track
            return {st, name of t, artist of t, album of t, duration of t, player position}
        end tell
        """
        guard let r = Self.run(script), r.numberOfItems >= 6,
              let state = r.atIndex(1)?.stringValue, state != "stopped" else { return nil }
        let title = r.atIndex(2)?.stringValue ?? ""
        guard !title.isEmpty else { return nil }
        var duration = r.atIndex(5)?.doubleValue ?? 0
        if p == .spotify { duration /= 1000 }   // Spotify reports milliseconds
        return Track(player: p, title: title, artist: r.atIndex(3)?.stringValue ?? "",
                     album: r.atIndex(4)?.stringValue ?? "", duration: duration,
                     position: r.atIndex(6)?.doubleValue ?? 0, positionAt: Date(),
                     playing: state == "playing" || state == "kPSP")
    }

    private func loadArtwork(_ t: Track) {
        artKey = t.key
        art = nil
        let key = t.key
        queue.async { [weak self] in
            var image: NSImage?
            switch t.player {
            case .music:
                if let d = Self.run("tell application id \"com.apple.Music\" to get raw data of artwork 1 of current track")?.data {
                    image = NSImage(data: d)
                } else if let d = Self.run("tell application id \"com.apple.Music\" to get data of artwork 1 of current track")?.data {
                    image = NSImage(data: d)
                }
            case .spotify:
                // Spotify only gives a link to the cover on its image server.
                if let s = Self.run("tell application id \"com.spotify.client\" to get artwork url of current track")?.stringValue,
                   let url = URL(string: s), url.scheme == "https",
                   let d = try? Data(contentsOf: url) {
                    image = NSImage(data: d)
                }
            }
            guard let image else { return }
            let tint = Self.averageColor(image)
            DispatchQueue.main.async {
                guard let self, self.artKey == key else { return }
                self.art = (image, tint)
                if var cur = self.track, cur.key == key {
                    cur.artwork = image
                    cur.tint = tint
                    self.track = cur
                    self.onChange(cur)
                }
            }
        }
    }

    /// The cover's average colour, brightened so it reads on the black island.
    static func averageColor(_ image: NSImage) -> NSColor {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(x: 0, y: 0, width: 1, height: 1))
        NSGraphicsContext.restoreGraphicsState()
        let c = rep.colorAt(x: 0, y: 0)?.usingColorSpace(.deviceRGB) ?? .white
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: h, saturation: min(0.85, s * 1.2 + 0.1), brightness: max(0.95, b), alpha: 1)
    }
}
