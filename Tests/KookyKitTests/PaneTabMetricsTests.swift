import SwiftUI
import XCTest
@testable import KookyKit

@MainActor
final class PaneTabMetricsTests: XCTestCase {
    func testCompactHeaderKeepsToolbarTargetsAndClearance() {
        XCTAssertLessThan(Theme.paneTabBarHeight, Theme.contentHeaderHeight)
        XCTAssertGreaterThanOrEqual(
            Theme.paneTabBarHeight - Theme.chromeToolbarButtonSize, 6
        )
    }

    func testRailTargetsRetainClearance() {
        XCTAssertEqual(Theme.paneTabRailHeight, Theme.chromeToolbarButtonSize)
        XCTAssertGreaterThanOrEqual(Theme.paneTabCloseButtonSize, 20)
        XCTAssertGreaterThanOrEqual(Theme.paneTabRailHeight - Theme.paneTabCloseButtonSize, 6)
        XCTAssertGreaterThanOrEqual(Theme.paneTabHorizontalInset, 8)
    }

    func testSelectedTabHasSmallUpperCornersAndNoLowerSeam() {
        let height = Theme.paneTabRailHeight + Theme.paneTabJoinHeight
        let frame = CGRect(x: 0, y: 0, width: Theme.paneTabMinimumWidth, height: height)
        let fill = PaneTabSelectionShape(radius: Theme.paneTabSelectionRadius).path(in: frame)
        XCTAssertEqual(Theme.paneTabRailHeight + 2 * Theme.paneTabJoinHeight, Theme.paneTabBarHeight)
        for x in [CGFloat(0.5), frame.midX, frame.maxX - 0.5] {
            XCTAssertTrue(fill.contains(CGPoint(x: x, y: height - 0.25)))
        }
        XCTAssertFalse(fill.contains(CGPoint(x: 0.5, y: 0.5)))
        XCTAssertFalse(fill.contains(CGPoint(x: frame.maxX - 0.5, y: 0.5)))
        XCTAssertTrue(fill.contains(CGPoint(x: frame.midX, y: 0.5)))
    }

    func testTabsFillAvailableRailOrScrollAtMinimumWidth() {
        XCTAssertEqual(Theme.paneTabWidth(available: 360, count: 2), 180)
        XCTAssertEqual(Theme.paneTabWidth(available: 300, count: 1), 300)
        XCTAssertEqual(Theme.paneTabWidth(available: 219, count: 2), 128)
        XCTAssertEqual(Theme.paneTabWidth(available: 0, count: 0), 128)
    }

    func testHintsMatchRealTabKeybindings() {
        XCTAssertEqual(MenuTag.shortcut(forTabIndex: 0, tabCount: 1), "⌘1")
        XCTAssertEqual(MenuTag.shortcut(forTabIndex: 7, tabCount: 12), "⌘8")
        XCTAssertNil(MenuTag.shortcut(forTabIndex: 8, tabCount: 12))
        XCTAssertEqual(MenuTag.shortcut(forTabIndex: 11, tabCount: 12), "⌘9")
        XCTAssertNil(MenuTag.shortcut(forTabIndex: 0, tabCount: 0))
        XCTAssertNil(MenuTag.shortcut(forTabIndex: -1, tabCount: 12))
    }
}
