import XCTest

final class LocalizedReadmeTests: XCTestCase {
    func testDownloadEntryIsVisibleBeforeFeaturesAndScreenshots() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        for name in ["README.md", "README_CN.md", "README_JA.md"] {
            let text = try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
            let introduction = try XCTUnwrap(text.components(separatedBy: "\n---\n").first)
            XCTAssertTrue(introduction.contains("## [↓ "), name)
            XCTAssertTrue(introduction.contains("https://github.com/uuuyuqi/kookoo/releases)"), name)
            XCTAssertTrue(introduction.contains("Apple silicon"), name)
            XCTAssertTrue(introduction.contains("Pre-release"), name)
            XCTAssertTrue(introduction.contains("Help → Check for Updates"), name)
            XCTAssertTrue(introduction.contains("ad-hoc"), name)
            XCTAssertFalse(introduction.contains("img/screenshot"), name)
            XCTAssertFalse(text.contains("/releases/latest"), name)
        }
    }

    func testLocalizedReadmesIdentifyIndependentPreviewDistribution() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        for name in ["README_CN.md", "README_JA.md"] {
            let text = try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
            XCTAssertTrue(text.hasPrefix("# Kookoo Terminal\n"), name)
            XCTAssertTrue(text.contains("https://github.com/uuuyuqi/kookoo/releases)"), name)
            XCTAssertTrue(text.contains("include_prereleases"), name)
            XCTAssertTrue(text.contains("Pre-release"), name)
            XCTAssertFalse(text.contains("/releases/latest"), name)
            XCTAssertFalse(text.contains("iAmCorey/kooky/releases"), name)
            XCTAssertTrue(text.contains("[Kooky](https://github.com/iAmCorey/kooky)"), name)
            XCTAssertTrue(text.contains("[LICENSE](LICENSE)"), name)
            XCTAssertTrue(text.contains("[NOTICE.md](NOTICE.md)"), name)
            XCTAssertTrue(text.contains("Kookoo.app/Contents/MacOS/kookoo-cli"), name)
            XCTAssertFalse(text.contains("spctl --global-disable"), name)
        }
    }
}
