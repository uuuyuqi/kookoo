import AppKit
import Observation

struct AppIconChoice: Identifiable, Equatable, Sendable {
    let id: String
    let name: String

    var localizedName: String {
        localizedName(in: .kookyResources)
    }

    func localizedName(in bundle: Bundle) -> String {
        bundle.localizedString(forKey: name, value: name, table: nil)
    }

    static let all: [Self] = [
        .init(id: "default", name: "Kookoo (Default)"),
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

        .init(id: "review-01", name: "Ivory K"),
        .init(id: "review-02", name: "Brushed Titanium"),
        .init(id: "review-03", name: "Burgundy Lacquer"),
        .init(id: "review-04", name: "Blue Porcelain"),
        .init(id: "review-05", name: "Saddle Leather"),
        .init(id: "review-06", name: "Cobalt Origami"),
        .init(id: "review-07", name: "Scarlet Cursor"),
        .init(id: "review-08", name: "Pistachio"),
        .init(id: "review-09", name: "Black & Gold"),
        .init(id: "review-10", name: "Midnight Pearl"),
        .init(id: "review-11", name: "Jelly Cat"),
        .init(id: "review-12", name: "Yuzu Smile"),
        .init(id: "review-13", name: "Ice Keycap"),
        .init(id: "review-14", name: "Pixel Cat"),
        .init(id: "review-15", name: "Neon Stickers"),
        .init(id: "review-16", name: "Acid Lightning"),
        .init(id: "review-17", name: "Orange Balloon"),
        .init(id: "review-18", name: "Milk Carton"),
        .init(id: "review-19", name: "Holo Alien"),
        .init(id: "review-20", name: "Violet Comet"),
        .init(id: "review-21", name: "Cyanotype Fern"),
        .init(id: "review-22", name: "Inkbrush K"),
        .init(id: "review-23", name: "Printed Sunset"),
        .init(id: "review-24", name: "Vermilion Seal"),
        .init(id: "review-25", name: "Woodcut Trail"),
        .init(id: "review-26", name: "Misty Moon"),
        .init(id: "review-27", name: "Paper Fan"),
        .init(id: "review-28", name: "Jade Sunrise"),
        .init(id: "review-29", name: "Terracotta Cursor"),
        .init(id: "review-30", name: "Inkfish"),
        .init(id: "review-31", name: "Oscilloscope"),
        .init(id: "review-32", name: "Green Screen"),
        .init(id: "review-33", name: "Split Flap"),
        .init(id: "review-34", name: "Amber CRT"),
        .init(id: "review-35", name: "Orange Terminal"),
        .init(id: "review-36", name: "Mixtape"),
        .init(id: "review-37", name: "Blueprint"),
        .init(id: "review-38", name: "Prism K"),
        .init(id: "review-39", name: "Pocket Pixels"),
        .init(id: "review-40", name: "Obsidian Armor"),
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
            lastError = String(format: String(localized: "Could not change the app icon: %@ Your saved preference was not changed; the selected icon could not be applied. Install Kookoo in a writable Applications folder; no administrator access is requested.", bundle: .kookyResources), error.localizedDescription)
            return false
        }
    }

    private enum IconError: LocalizedError {
        case invalidChoice, invalidImage, invalidTarget
        var errorDescription: String? {
            switch self {
            case .invalidChoice: String(localized: "Unknown icon.", bundle: .kookyResources)
            case .invalidImage: String(localized: "The bundled icon is missing or invalid.", bundle: .kookyResources)
            case .invalidTarget: String(localized: "The app icon is not a regular file.", bundle: .kookyResources)
            }
        }
    }
}
