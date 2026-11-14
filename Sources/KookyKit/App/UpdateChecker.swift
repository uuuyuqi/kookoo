import Foundation

/// Manual-download fallback when the signed in-app updater is not configured.
/// Preview builds include prereleases; stable builds deliberately exclude them.
enum UpdateChecker {
    enum Outcome {
        case upToDate(current: String)
        case newer(latest: String, url: URL, releaseNotes: String)
        case failed(String)
    }

    struct Release: Decodable {
        let tagName: String
        let htmlUrl: String
        let body: String?
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: String
            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadUrl = "browser_download_url"
            }
        }
        enum CodingKeys: String, CodingKey {
            case body, assets, draft, prerelease
            case tagName = "tag_name"
            case htmlUrl = "html_url"
        }
    }

    static func check(currentVersion: String = KookyApp.displayVersion,
                      includePrereleases: Bool = KookyApp.isPreview,
                      session: URLSession = .shared) async -> Outcome {
        // /latest excludes prereleases. Fetch a bounded, published release list instead.
        var request = URLRequest(url: KookyApp.releasesAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failed("No response from GitHub.") }
            guard http.statusCode == 200 else { return .failed("GitHub returned HTTP \(http.statusCode).") }
            return outcome(data: data, currentVersion: currentVersion, includePrereleases: includePrereleases)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    static func outcome(data: Data, currentVersion: String, includePrereleases: Bool) -> Outcome {
        guard let current = ReleaseVersion(currentVersion) else { return .failed("Invalid current version.") }
        do {
            let releases = try JSONDecoder().decode([Release].self, from: data)
            let candidates = releases.compactMap { release -> (Release, ReleaseVersion)? in
                guard !release.draft,
                      includePrereleases || !release.prerelease,
                      let version = ReleaseVersion(release.tagName),
                      includePrereleases || version.prerelease.isEmpty else { return nil }
                return (release, version)
            }
            guard let (release, version) = candidates.max(by: { $0.1 < $1.1 }), version > current else {
                return .upToDate(current: currentVersion)
            }
            let asset = release.assets.first { $0.name.lowercased().hasSuffix(".dmg") }
            let urlString = asset?.browserDownloadUrl ?? release.htmlUrl
            guard let url = URL(string: urlString), url.scheme == "https", url.host == "github.com",
                  url.path.hasPrefix("/uuuyuqi/kookoo/releases/") else {
                return .failed("The release download URL is not a trusted Kookoo URL.")
            }
            return .newer(latest: Version.stripLeadingV(release.tagName), url: url,
                          releaseNotes: release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        } catch {
            return .failed("Couldn't read GitHub releases: \(error.localizedDescription)")
        }
    }
}

/// SemVer ordering for release selection; keeps preview < stable and ignores build metadata.
struct ReleaseVersion: Comparable {
    let core: [Int]
    let prerelease: [String]

    init?(_ text: String) {
        let version = Version.stripLeadingV(text)
        let noBuild = version.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)[0]
        let parts = noBuild.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let fields = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard fields.count == 3, fields.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              fields.allSatisfy({ $0.count == 1 || $0.first != "0" }) else { return nil }
        let numbers = fields.compactMap { Int($0) }
        guard numbers.count == 3 else { return nil }
        core = numbers
        if parts.count == 2 {
            let ids = parts[1].split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            guard ids.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 } }),
                  ids.allSatisfy({ !$0.allSatisfy(\.isNumber) || $0.count == 1 || !$0.hasPrefix("0") }) else { return nil }
            prerelease = ids
        } else { prerelease = [] }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.core != rhs.core { return lhs.core.lexicographicallyPrecedes(rhs.core) }
        if lhs.prerelease.isEmpty { return false }
        if rhs.prerelease.isEmpty { return true }
        for (a, b) in zip(lhs.prerelease, rhs.prerelease) where a != b {
            let an = a.allSatisfy(\.isNumber), bn = b.allSatisfy(\.isNumber)
            if an && bn { return a.count == b.count ? a < b : a.count < b.count }
            if an != bn { return an }
            return a < b
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }
}
