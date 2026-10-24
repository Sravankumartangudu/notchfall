import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// 📂 Files parked on the shelf: drag them to the notch, drag them out again wherever they're needed.
/// Only the file paths are kept (in UserDefaults); files that have since moved or been deleted drop off.
final class Shelf {
    private let key = "shelf"
    private(set) var items: [URL] = []
    static let limit = 12

    init() {
        items = (UserDefaults.standard.stringArray(forKey: key) ?? []).map { URL(fileURLWithPath: $0) }
        prune()
    }

    /// Newest first; adding a file that's already there moves it to the front.
    func add(_ urls: [URL]) {
        let files = urls.filter(\.isFileURL)
        items.removeAll { u in files.contains { $0.path == u.path } }
        items = Array((files + items).prefix(Self.limit))
        save()
    }

    func remove(_ url: URL) {
        items.removeAll { $0.path == url.path }
        save()
    }

    func clear() {
        items = []
        save()
    }

    func prune() {
        let kept = items.filter { FileManager.default.fileExists(atPath: $0.path) }
        if kept != items { items = kept; save() }
    }

    private func save() { UserDefaults.standard.set(items.map(\.path), forKey: key) }

    /// Made-up files for previews and screenshots (they don't exist, so they're drawn with type icons).
    static let demo = ["Q3 Roadmap.key", "Invoice-1042.pdf", "Team offsite.jpg", "notes.md", "build.zip"]
        .map { URL(fileURLWithPath: "/tmp/notchfall-demo/\($0)") }

    static func icon(_ url: URL) -> NSImage {
        if FileManager.default.fileExists(atPath: url.path) { return NSWorkspace.shared.icon(forFile: url.path) }
        return NSWorkspace.shared.icon(for: UTType(filenameExtension: url.pathExtension) ?? .data)
    }

    static func airDrop(_ urls: [URL]) {
        guard !urls.isEmpty, let s = NSSharingService(named: .sendViaAirDrop) else { return }
        NSApp.activate()
        s.perform(withItems: urls)
    }
}

/// Shown while a file is dragged up to the notch: drop it on the shelf, or straight onto AirDrop.
struct DropContent: View {
    @ObservedObject var m: IslandModel
    let inset: CGFloat

    var body: some View {
        let on = m.showContent
        VStack(spacing: 0) {
            Wings(m: m) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.to.line").font(.system(size: 10, weight: .bold))
                    Text("DROP HERE").kerning(0.6)
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .reveal(on, 0.02)
            } right: {
                Text(m.shelf.isEmpty ? "Shelf is empty" : "\(m.shelf.count) on the shelf")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .reveal(on, 0.04)
            }
            .padding(.horizontal, 4)

            HStack(spacing: 10) {
                DropZone(m: m, id: "shelf", symbol: "tray.and.arrow.down.fill", title: "Shelf",
                         detail: "Keep it here for later", tint: rgb(1, 0.76, 0.32)) { m.onShelfDrop($0) }
                    .reveal(on, 0.06)
                DropZone(m: m, id: "airdrop", symbol: "dot.radiowaves.left.and.right", title: "AirDrop",
                         detail: "Send to a nearby device", tint: rgb(0.32, 0.62, 1)) { Shelf.airDrop($0) }
                    .reveal(on, 0.1)
            }
            .padding(.top, 10)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, inset)
        .padding(.bottom, 16)
    }
}

private struct DropZone: View {
    @ObservedObject var m: IslandModel
    let id: String
    let symbol: String
    let title: String
    let detail: String
    let tint: Color
    let drop: ([URL]) -> Void
    @State private var targeted = false

    var body: some View {
        let hot = targeted || m.demoDropTarget == id
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(hot ? .black : tint)
                .frame(width: 42, height: 42)
                .background(Circle().fill(hot ? tint : tint.opacity(0.16)))
                .symbolEffect(.bounce, value: hot)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                Text(detail).font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .background(shape.fill(tint.opacity(hot ? 0.2 : 0.05)))
        .overlay(shape.strokeBorder(tint.opacity(hot ? 0.9 : 0.35), style: StrokeStyle(lineWidth: 1.5, dash: hot ? [] : [6, 5])))
        .scaleEffect(hot ? 1.03 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hot)
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter(\.isFileURL)
            guard !files.isEmpty else { return false }
            drop(files)
            return true
        } isTargeted: { targeted = $0 }
    }
}

/// The shelf under "Up next": drag a file out to use it, double-click to open, ✕ to take it off.
struct ShelfStrip: View {
    @ObservedObject var m: IslandModel
    static let height: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "tray.full.fill").font(.system(size: 10, weight: .bold))
                Text("SHELF").kerning(0.6)
                Text("\(m.shelf.count)").foregroundStyle(.white.opacity(0.4))
                Spacer()
                Button { Shelf.airDrop(m.shelf) } label: {
                    Label("AirDrop", systemImage: "dot.radiowaves.left.and.right")
                }
                .buttonStyle(IslandButtonStyle())
                .help("Send everything on the shelf with AirDrop")
                Button { m.onShelfRemove(nil) } label: { Text("Clear") }
                    .buttonStyle(IslandButtonStyle())
                    .help("Take everything off the shelf (the files themselves stay put)")
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(rgb(1, 0.76, 0.32))
            .controlSize(.small)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(m.shelf, id: \.path) { url in ShelfTile(m: m, url: url) }
                }
            }
        }
        .frame(height: Self.height - 8, alignment: .top)
        .padding(.horizontal, 8)
    }
}

private struct ShelfTile: View {
    @ObservedObject var m: IslandModel
    let url: URL
    @State private var hover = false

    var body: some View {
        VStack(spacing: 3) {
            Image(nsImage: Shelf.icon(url)).resizable().interpolation(.high).frame(width: 34, height: 34)
            Text(url.lastPathComponent)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: 66, height: 56)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(hover ? 0.1 : 0.05)))
        .overlay(alignment: .topTrailing) {
            if hover {
                Button { m.onShelfRemove(url) } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .offset(x: 3, y: -3)
                .help("Take off the shelf")
            }
        }
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(url) }
        .onDrag {
            m.draggingOut = true   // our own drag mustn't open the drop zones
            return NSItemProvider(contentsOf: url) ?? NSItemProvider()
        }
        .help(url.path)
    }
}
