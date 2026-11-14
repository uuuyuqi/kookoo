import XCTest
@testable import KookyKit

final class UpdateCheckerTests: XCTestCase {
    private func release(_ version: String, preview: Bool = false, draft: Bool = false,
                         url: String = "https://github.com/uuuyuqi/kookoo/releases/download/v0.2.0/Kookoo.dmg") -> [String: Any] {
        ["tag_name": version, "prerelease": preview, "draft": draft,
         "html_url": "https://github.com/uuuyuqi/kookoo/releases/tag/\(version)",
         "body": "Notes", "assets": [["name": "Kookoo.dmg", "browser_download_url": url]]]
    }
    private func check(_ releases: [[String: Any]], previews: Bool) throws -> UpdateChecker.Outcome {
        UpdateChecker.outcome(data: try JSONSerialization.data(withJSONObject: releases),
                              currentVersion: "0.1.1", includePrereleases: previews)
    }
    func testPreviewChannelFindsPreview() throws {
        guard case .newer(let latest, _, _) = try check([release("v0.2.0", preview: true)], previews: true) else {
            return XCTFail("Preview must be offered")
        }
        XCTAssertEqual(latest, "0.2.0")
    }
    func testStableExcludesPreviewsAndDrafts() throws {
        guard case .upToDate = try check([release("v0.2.0", preview: true), release("v0.3.0", draft: true)], previews: false) else {
            return XCTFail("Must not offer preview/draft")
        }
    }
    func testPreviewAlsoExcludesDrafts() throws {
        guard case .upToDate = try check([release("v0.3.0", draft: true)], previews: true) else { return XCTFail() }
    }
    func testSelectsHighestNotFirstRelease() throws {
        guard case .newer(let latest, _, _) = try check([release("v0.2.0"), release("v0.10.0"), release("v0.3.0")], previews: true) else { return XCTFail() }
        XCTAssertEqual(latest, "0.10.0")
    }
    func testNoDowngradeAndInvalidTagsIgnored() throws {
        guard case .upToDate = try check([release("v0.1.0"), release("hello"), release("v0.1.1")], previews: true) else { return XCTFail() }
    }
    func testUntrustedDownloadRejected() throws {
        guard case .failed = try check([release("v0.2.0", url: "https://evil.example/update.dmg")], previews: true) else { return XCTFail() }
    }
    func testBadJSONFails() {
        guard case .failed = UpdateChecker.outcome(data: Data("bad".utf8), currentVersion: "0.1.1", includePrereleases: true) else { return XCTFail() }
    }
    func testSemverOrdering() throws {
        let versions = ["0.2.0-alpha", "0.2.0-alpha.2", "0.2.0-alpha.10", "0.2.0-beta", "0.2.0-rc.1", "0.2.0"]
        let parsed = try versions.map { try XCTUnwrap(ReleaseVersion($0)) }
        XCTAssertEqual(parsed.sorted(), parsed)
        XCTAssertEqual(ReleaseVersion("0.2.0+build.2"), ReleaseVersion("0.2.0"))
        XCTAssertNil(ReleaseVersion("0.2.0-01"))
    }
    func testMissingTrustDisablesInAppInstallation() {
        XCTAssertNil(UpdateTrustConfiguration(info: [:]))
        XCTAssertNil(UpdateTrustConfiguration(info: ["SUPublicEDKey": "placeholder"]))
    }
    func testTrustRequiresPinnedHTTPSFeedAndValidKey() {
        // Public-only test fixture. There is no private counterpart or production use.
        let publicKey = Data(repeating: 7, count: 32).base64EncodedString()
        var info: [String: Any] = ["SUPublicEDKey": publicKey,
                                  "SUFeedURL": "https://raw.githubusercontent.com/uuuyuqi/kookoo/main/appcast.xml",
                                  "SUVerifyUpdateBeforeExtraction": true]
        XCTAssertNotNil(UpdateTrustConfiguration(info: info))
        info["SUFeedURL"] = "http://example.com/feed.xml"
        XCTAssertNil(UpdateTrustConfiguration(info: info))
    }
}
