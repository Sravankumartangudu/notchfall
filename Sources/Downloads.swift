import Foundation

/// ⏳ Downloads in progress in ~/Downloads, from any browser: Safari's .download bundles (which carry
/// their progress), and Chrome, Edge, Brave or Arc's .crdownload and Firefox's .part files (size only).
/// Only file names, sizes and Safari's progress numbers are looked at, never the contents.
final class Downloads {
    struct Item: Equatable {
        let path: String
        let name: String          // the finished file's name, as far as it's known
        var bytes: Int64
        var total: Int64?
    }

    var onChange: ([Item]) -> Void = { _ in }
    var onFinished: (URL) -> Void = { _ in }
    var enabled = true
    private(set) var items: [Item] = []
    private var timer: Timer?
    private let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]

    func start() {
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private var names: Set<String>?

    private func poll() {
        guard enabled else { if !items.isEmpty { items = []; onChange([]) }; names = nil; return }
        let fm = FileManager.default
        guard let list = try? fm.contentsOfDirectory(atPath: folder.path) else { return }
        let listed = Set(list)
        var now: [Item] = []
        for name in list {
            let path = folder.appendingPathComponent(name).path
            if name.hasSuffix(".download") {
                // Only Safari's progress numbers are read from its Info.plist.
                let plist = NSDictionary(contentsOfFile: path + "/Info.plist")
                let done = (plist?["DownloadEntryProgressBytesSoFar"] as? NSNumber)?.int64Value ?? Self.size(path)
                let total = (plist?["DownloadEntryProgressTotalToLoad"] as? NSNumber)?.int64Value
                now.append(Item(path: path, name: String(name.dropLast(".download".count)), bytes: done,
                                total: total.flatMap { $0 > 0 ? $0 : nil }))
            } else if Self.partial(name) {
                let base = (name as NSString).deletingPathExtension
                now.append(Item(path: path, name: base.hasPrefix("Unconfirmed ") ? "" : base, bytes: Self.size(path), total: nil))
            }
        }
        // A download that crashed or failed leaves its partial file behind: once nothing has been
        // written to it for a minute and a half, it no longer counts as downloading.
        now = now.filter { Date().timeIntervalSince(Self.modified($0.path)) < 90 }
        now.sort { $0.path < $1.path }
        let gone = items.filter { old in !now.contains { $0.path == old.path } }
        if now != items { items = now; onChange(now) }
        // What's new in the folder since the last look. A download that was only renamed (Chrome's
        // "Unconfirmed 123" becoming "photos.zip.crdownload") or cancelled leaves no new file behind.
        let fresh = names.map { listed.subtracting($0) } ?? []
        names = listed
        let newFinal = fresh.filter { !Self.partial($0) && !$0.hasSuffix(".download") && !$0.hasPrefix(".") }
        let newPartial = fresh.contains { Self.partial($0) || $0.hasSuffix(".download") }
        var reported = Set<String>()
        for g in gone {
            let name: String?
            if !g.name.isEmpty { name = newFinal.contains(g.name) ? g.name : nil }
            else { name = !newPartial && newFinal.count == 1 ? newFinal.first : nil }
            if let name, reported.insert(name).inserted { onFinished(folder.appendingPathComponent(name)) }
        }
    }

    private static func partial(_ name: String) -> Bool { name.hasSuffix(".crdownload") || name.hasSuffix(".part") }

    /// When something was last written: for Safari's bundles, the newest file inside.
    private static func modified(_ path: String) -> Date {
        let fm = FileManager.default
        var latest = (try? fm.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? .distantPast
        if path.hasSuffix(".download"), let files = fm.enumerator(atPath: path) {
            for case let f as String in files {
                if let d = try? fm.attributesOfItem(atPath: path + "/" + f)[.modificationDate] as? Date, d > latest { latest = d }
            }
        }
        return latest
    }

    private static func size(_ path: String) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue { return (try? fm.attributesOfItem(atPath: path)[.size] as? NSNumber)??.int64Value ?? 0 }
        var total: Int64 = 0
        guard let files = fm.enumerator(atPath: path) else { return 0 }
        for case let f as String in files where f != "Info.plist" {
            total += (try? fm.attributesOfItem(atPath: path + "/" + f)[.size] as? NSNumber)??.int64Value ?? 0
        }
        return total
    }

    /// One line for the wings: "42%", "12.4 MB", or "3 downloads · 42%".
    static func activity(_ items: [Item]) -> Activity? {
        guard !items.isEmpty else { return nil }
        let known = items.compactMap { i in i.total.map { (i.bytes, $0) } }
        let progress: Double? = known.count == items.count
            ? Double(known.map(\.0).reduce(0, +)) / Double(max(1, known.map(\.1).reduce(0, +))) : nil
        let size = ByteCountFormatter.string(fromByteCount: items.map(\.bytes).reduce(0, +), countStyle: .file)
        let amount = progress.map { "\(Int(($0 * 100).rounded(.down)))%" } ?? size
        return Activity(id: "downloads", symbol: "arrow.down", tint: rgb(0.36, 0.7, 1),
                        label: items.count == 1 ? amount : "\(items.count) files · \(amount)", progress: progress.map { min(1, $0) })
    }
}
