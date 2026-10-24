import AppKit

/// 🤖 Claude Code → the notch. Two hooks in ~/.claude/settings.json (Stop: Claude finished; Notification:
/// Claude needs you) drop what Claude Code sends them into ~/.notchfall/inbox, where the notch picks it up.
/// They're only added or removed when you choose to from the menu, and the old file is backed up first.
enum ClaudeHooks {
    static let settingsFile = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude/settings.json")
    private static let marker = "#notchfall-claude-hook"
    private static let events = ["Stop", "Notification"]

    /// Writes the hook's input (plus which Claude Code front end and terminal it came from) to a dot-file,
    /// then renames it into place, so the notch never reads a half-written file. Never fails the hook.
    static let command = #"d="$HOME/.notchfall/inbox"; mkdir -p "$d"; f="$d/.claude-$$"; { printf '{"source":"claude","entry":"%s","term":"%s","hook":' "$CLAUDE_CODE_ENTRYPOINT" "$TERM_PROGRAM"; cat; printf '}'; } > "$f" && mv "$f" "$d/claude-$$-$(date +%s).json" || true #notchfall-claude-hook"#

    static var claudeInstalled: Bool { FileManager.default.fileExists(atPath: settingsFile.deletingLastPathComponent().path) }

    static var installed: Bool {
        guard let hooks = read()?["hooks"] as? [String: Any] else { return false }
        return events.allSatisfy { e in groups(hooks[e]).contains { !ours($0).isEmpty } }
    }

    /// Adds (or removes) the two hooks, leaving every other setting and hook as it was. A file that isn't
    /// valid JSON is left alone. The first change backs the file up, and that backup is kept for good.
    @discardableResult static func set(_ on: Bool, file: URL = settingsFile) -> Bool {
        let fm = FileManager.default
        let file = file.resolvingSymlinksInPath()   // a dotfiles symlink stays a symlink
        var root: [String: Any] = [:]
        if fm.fileExists(atPath: file.path) {
            guard let r = read(file) else { return false }
            root = r
            let backup = file.appendingPathExtension("notchfall-backup")
            if !fm.fileExists(atPath: backup.path) {
                guard (try? fm.copyItem(at: file, to: backup)) != nil else { return false }
            }
        } else if !on {
            return true
        }
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for e in events {
            // Take out only our own hook, keeping anything else that shares its group.
            var list: [[String: Any]] = groups(hooks[e]).compactMap { g in
                let own = ours(g)
                guard !own.isEmpty else { return g }
                var g = g
                let rest = (g["hooks"] as? [[String: Any]] ?? []).enumerated().filter { !own.contains($0.offset) }.map(\.element)
                if rest.isEmpty { return nil }
                g["hooks"] = rest
                return g
            }
            if on { list.append(["matcher": "", "hooks": [["type": "command", "command": command, "timeout": 5]]]) }
            hooks[e] = list.isEmpty ? nil : list
        }
        root["hooks"] = hooks.isEmpty ? nil : hooks
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys])
        else { return false }
        try? fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? data.write(to: file, options: .atomic)) != nil
    }

    private static func read(_ file: URL = settingsFile) -> [String: Any]? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func groups(_ v: Any?) -> [[String: Any]] { v as? [[String: Any]] ?? [] }

    /// The positions of our hooks within a group.
    private static func ours(_ group: [String: Any]) -> Set<Int> {
        Set((group["hooks"] as? [[String: Any]] ?? []).enumerated()
            .filter { ($0.element["command"] as? String)?.contains(marker) == true }.map(\.offset))
    }

    // MARK: Reading what the hooks send

    /// Editors and terminals where you'd already see Claude finish.
    static let lookingAt: Set<String> = ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.apple.Terminal",
                                         "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.mitchellh.ghostty",
                                         "com.todesktop.230313mzl4w4u92", "com.anthropic.claudefordesktop",
                                         "net.kovidgoyal.kitty", "com.github.wez.wezterm", "co.zeit.hyper"]

    /// The app to bring forward from the card, from $TERM_PROGRAM or the Claude Code front end.
    static func app(term: String, entry: String) -> URL? {
        let ids: [String: String] = ["Apple_Terminal": "com.apple.Terminal", "iTerm.app": "com.googlecode.iterm2",
                                     "vscode": "com.microsoft.VSCode", "WarpTerminal": "dev.warp.Warp-Stable",
                                     "ghostty": "com.mitchellh.ghostty", "WezTerm": "com.github.wez.wezterm"]
        let id = ids[term] ?? (entry.contains("vscode") ? "com.microsoft.VSCode" : entry.contains("desktop") ? "com.anthropic.claudefordesktop" : nil)
        return id.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
    }

    /// The first line of Claude's last reply, read from the end of the session transcript.
    static func lastReply(_ transcript: String?) -> String? {
        guard let path = transcript, let h = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? h.close() }
        let end = (try? h.seekToEnd()) ?? 0
        try? h.seek(toOffset: end > 262_144 ? end - 262_144 : 0)
        guard let data = try? h.readToEnd() else { return nil }
        let text = String(decoding: data, as: UTF8.self)   // the cut may land mid-character
        for line in text.split(separator: "\n").reversed() {
            guard line.contains("\"assistant\""), let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  obj["type"] as? String == "assistant",
                  let content = (obj["message"] as? [String: Any])?["content"] as? [[String: Any]] else { continue }
            for part in content.reversed() where part["type"] as? String == "text" {
                let s = (part["text"] as? String ?? "").split(whereSeparator: \.isNewline)
                    .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "#*`>- ")) }
                    .first { !$0.isEmpty }
                if let s { return s.count > 140 ? String(s.prefix(139)) + "…" : s }
            }
        }
        return nil
    }
}
