import AppKit
import XCTest
@testable import KookyKit

@MainActor
final class AppIconControllerTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite: String!
    private var pearl: Data!
    private var neon: Data!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("IconChoices"), withIntermediateDirectories: true)
        suite = "kookoo.icon-tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        pearl = try Data(contentsOf: repository.appendingPathComponent("branding/alternates/01-pearl.icns"))
        neon = try Data(contentsOf: repository.appendingPathComponent("branding/alternates/03-neon.icns"))
        try pearl.write(to: root.appendingPathComponent("IconChoices/01-pearl.icns"))
        try neon.write(to: root.appendingPathComponent("IconChoices/default.icns"))
        try neon.write(to: root.appendingPathComponent("AppIcon.icns"))
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        try FileManager.default.removeItem(at: root)
    }

    func testCatalogHasTwentyUniqueAlternatesAndDefault() {
        XCTAssertEqual(AppIconChoice.all.count, 21)
        XCTAssertEqual(Set(AppIconChoice.all.map(\.id)).count, 21)
        XCTAssertEqual(AppIconChoice.all.first?.id, "default")
    }

    func testSelectPersistsOnlyAfterWriteAndUpdatesDock() throws {
        var displayed = false
        let controller = AppIconController(resources: root, defaults: defaults, display: { _ in displayed = true })
        XCTAssertTrue(controller.select("01-pearl"))
        XCTAssertTrue(displayed)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("AppIcon.icns")), pearl)
        XCTAssertEqual(defaults.string(forKey: AppIconController.preferenceKey), "01-pearl")
    }

    func testWriteFailurePreservesFilePreferenceAndDock() throws {
        defaults.set("default", forKey: AppIconController.preferenceKey)
        var displayed = false
        let controller = AppIconController(resources: root, defaults: defaults, display: { _ in displayed = true }, write: { _, _ in
            throw CocoaError(.fileWriteNoPermission)
        })
        XCTAssertFalse(controller.select("01-pearl"))
        XCTAssertFalse(displayed)
        XCTAssertEqual(controller.selectedID, "default")
        XCTAssertEqual(defaults.string(forKey: AppIconController.preferenceKey), "default")
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("AppIcon.icns")), neon)
        XCTAssertNotNil(controller.lastError)
    }

    func testUpgradeReappliesChoiceAndDefaultUsesNewVersionCanonical() throws {
        defaults.set("01-pearl", forKey: AppIconController.preferenceKey)
        let controller = AppIconController(resources: root, defaults: defaults, display: { _ in })
        controller.restoreAtLaunch()
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("AppIcon.icns")), pearl)
        XCTAssertTrue(controller.select("default"))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("AppIcon.icns")), neon)
    }

    func testUnchangedRestartDoesNotWrite() throws {
        defaults.set("01-pearl", forKey: AppIconController.preferenceKey)
        try pearl.write(to: root.appendingPathComponent("AppIcon.icns"))
        var writes = 0
        let controller = AppIconController(resources: root, defaults: defaults, display: { _ in }, write: { _, _ in writes += 1 })
        controller.restoreAtLaunch()
        XCTAssertEqual(writes, 0)
        XCTAssertNil(controller.lastError)
    }

    func testMissingInvalidAndPathTraversalChoicesDoNotPersist() throws {
        let controller = AppIconController(resources: root, defaults: defaults, display: { _ in XCTFail("Should not display") })
        XCTAssertFalse(controller.select("../../outside"))
        XCTAssertFalse(controller.select("02-marshmallow"))
        try Data("broken".utf8).write(to: root.appendingPathComponent("IconChoices/01-pearl.icns"))
        XCTAssertFalse(controller.select("01-pearl"))
        XCTAssertNil(defaults.string(forKey: AppIconController.preferenceKey))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("AppIcon.icns")), neon)
    }

    func testUnknownSavedChoiceDoesNotModifyAppAtStartup() throws {
        defaults.set("removed-icon", forKey: AppIconController.preferenceKey)
        let controller = AppIconController(resources: root, defaults: defaults, display: { _ in XCTFail("Should not display") })
        controller.restoreAtLaunch()
        XCTAssertEqual(controller.selectedID, "default")
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("AppIcon.icns")), neon)
    }

    func testSymlinkTargetRejected() throws {
        let target = root.appendingPathComponent("AppIcon.icns")
        try FileManager.default.removeItem(at: target)
        try FileManager.default.createSymbolicLink(at: target, withDestinationURL: root.appendingPathComponent("IconChoices/default.icns"))
        let controller = AppIconController(resources: root, defaults: defaults, display: { _ in XCTFail("Should not display") })
        XCTAssertFalse(controller.select("01-pearl"))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("IconChoices/default.icns")), neon)
    }
}
