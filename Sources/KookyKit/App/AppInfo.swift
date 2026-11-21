import Foundation

/// Single source of truth for product metadata — surfaced by the About panel,
/// Help menu, and window title. Bump `displayVersion` on every release so the
/// About panel matches the latest CHANGELOG `vX.Y` tag.
enum KookyApp {
    static let name = "Kookoo"
    static let displayVersion = "0.1.15"
    static let isPreview = true
    static let tagline = "A minimal modern terminal for AI coding"
    static let author = "uuuyuqi · based on Kooky by Corey Chiu"
    static let authorURL = URL(string: "https://github.com/uuuyuqi/kookoo")!
    static let copyrightYear = "2026"

    static let repositoryURL = URL(string: "https://github.com/uuuyuqi/kookoo")!
    static let issuesURL = URL(string: "https://github.com/uuuyuqi/kookoo/issues")!
    /// Mirrors `repositoryURL`; update both if the repo is ever renamed.
    static let releasesAPIURL = URL(string: "https://api.github.com/repos/uuuyuqi/kookoo/releases?per_page=100")!
}
