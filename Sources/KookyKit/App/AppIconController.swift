import AppKit
import Observation

struct AppIconChoice: Identifiable, Equatable, Sendable {
    let id: String
    let name: String

    static let all: [Self] = [
        .init(id: "default", name: "Kookoo"),
        .init(id: "01-pearl", name: "Pearl"), .init(id: "02-marshmallow", name: "Marshmallow"),
        .init(id: "03-neon", name: "Neon"), .init(id: "04-retro", name: "Retro"),
        .init(id: "05-ink", name: "Ink"), .init(id: "06-jelly", name: "Jelly"),
        .init(id: "07-chrome", name: "Chrome"), .init(id: "08-pixel", name: "Pixel"),
        .init(id: "09-hacker", name: "Hacker"), .init(id: "10-swiss", name: "Swiss"),
        .init(id: "11-porcelain", name: "Porcelain"), .init(id: "12-sunset", name: "Sunset"),
        .init(id: "13-velvet", name: "Velvet"), .init(id: "14-space", name: "Space"),
        .init(id: "15-noir", name: "Noir"), .init(id: "16-ocean", name: "Ocean"),
        .init(id: "17-bauhaus", name: "Bauhaus"), .init(id: "18-peach", name: "Peach"),
        .init(id: "19-graphite", name: "Graphite"), .init(id: "20-prism", name: "Prism"),
    ]
}

/// Only AppIcon.icns is mutable. IconChoices is a signed-in source collection,
/// including THIS version's default. No cache clearing, re-signing or elevation.
@Observable @MainActor
public final class AppIconController {
    public static let shared = AppIconController(
        resources: Bundle.main.bundleURL.appendingPathComponent("Contents/Resources"),
        defaults: .standard,
        display: { NSApplication.shared.applicationIconImage = $0 }
    )
    static let preferenceKey = "kookoo.appIconID"
    private let resources: URL
    private let defaults: UserDefaults
    private let display: (NSImage) -> Void
    private let write: (Data, URL) throws -> Void
    private(set) var selectedID: String
    private(set) var lastError: String?

    init(resources: URL, defaults: UserDefaults, display: @escaping (NSImage) -> Void,
         write: @escaping (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }) {
        self.resources = resources
        self.defaults = defaults
        self.display = display
        self.write = write
        let saved = defaults.string(forKey: Self.preferenceKey) ?? "default"
        selectedID = AppIconChoice.all.contains { $0.id == saved } ? saved : "default"
    }

    func image(for id: String) -> NSImage? {
        guard AppIconChoice.all.contains(where: { $0.id == id }) else { return nil }
        return NSImage(contentsOf: source(for: id))
    }

    private func source(for id: String) -> URL {
        resources.appendingPathComponent("IconChoices/\(id).icns")
    }

    /// Called immediately after NSApplication creation, before windows/Ghostty.
    /// On upgrades, the new version's immutable source reapplies the preference.
    /// Failure is visible in Settings and never prevents terminal startup.
    public func restoreAtLaunch() {
        guard selectedID != "default" else { return }
        select(selectedID)
    }

    @discardableResult
    func select(_ id: String) -> Bool {
        do {
            guard AppIconChoice.all.contains(where: { $0.id == id }) else {
                throw IconError.invalidChoice
            }
            let data = try Data(contentsOf: source(for: id))
            guard data.starts(with: Data("icns".utf8)), let image = NSImage(data: data) else {
                throw IconError.invalidImage
            }
            let target = resources.appendingPathComponent("AppIcon.icns")
            let values = try target.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw IconError.invalidTarget
            }
            // No-op on ordinary restarts. Atomic replacement protects against
            // partial ICNS writes; preference is committed only after success.
            if try Data(contentsOf: target) != data { try write(data, target) }
            display(image)
            defaults.set(id, forKey: Self.preferenceKey)
            selectedID = id
            lastError = nil
            return true
        } catch {
            lastError = "Could not change the app icon: \(error.localizedDescription) Your saved preference was not changed; the selected icon could not be applied. Install Kookoo in a writable Applications folder; no administrator access is requested."
            return false
        }
    }

    private enum IconError: LocalizedError {
        case invalidChoice, invalidImage, invalidTarget
        var errorDescription: String? {
            switch self {
            case .invalidChoice: "Unknown icon."
            case .invalidImage: "The bundled icon is missing or invalid."
            case .invalidTarget: "The app icon is not a regular file."
            }
        }
    }
}
