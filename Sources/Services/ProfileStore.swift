import Foundation
import AppKit

/// Mirrors the Hunter's baseline as a Markdown file in Application Support — visible
/// to the user, easy to edit, and a clean blob to drop into AI prompts.
enum ProfileStore {
    /// Default location: ~/Library/Application Support/SoloLevelingDaily/profile.md
    /// (Sandboxed apps land at ~/Library/Containers/<bundle>/Data/Library/Application Support/...)
    static var profileURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = base.appendingPathComponent("SoloLevelingDaily", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("profile.md")
    }

    @discardableResult
    static func write(_ markdown: String) -> Bool {
        guard let url = profileURL else { return false }
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    static func read() -> String? {
        guard let url = profileURL,
              let data = try? Data(contentsOf: url),
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    static func revealInFinder() {
        guard let url = profileURL else { return }
        if !FileManager.default.fileExists(atPath: url.path) {
            _ = write("# Hunter Profile\n\n(Fill this out from the app's Settings → Personal Baseline.)\n")
        }
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }
}
