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

    func testSelectedChipHasFourSmallCornersAndGapFromTerminal() {
        let gap = (Theme.paneTabBarHeight - Theme.paneTabRailHeight) / 2 + Theme.paneTabChipVerticalInset
        XCTAssertEqual(gap, 4)
        let frame = CGRect(
            x: 0, y: 0,
            width: Theme.paneTabMinimumWidth - 2 * Theme.paneTabChipHorizontalInset,
            height: Theme.paneTabRailHeight - 2 * Theme.paneTabChipVerticalInset
        )
        let fill = RoundedRectangle(cornerRadius: Theme.paneTabSelectionRadius, style: .circular).path(in: frame)
        XCTAssertLessThan(Theme.paneTabSelectionRadius, frame.height / 3)
        for x in [CGFloat(0.5), frame.maxX - 0.5] {
            XCTAssertFalse(fill.contains(CGPoint(x: x, y: 0.5)))
            XCTAssertFalse(fill.contains(CGPoint(x: x, y: frame.maxY - 0.5)))
            XCTAssertTrue(fill.contains(CGPoint(x: x, y: frame.midY)))
        }
        XCTAssertTrue(fill.contains(CGPoint(x: frame.midX, y: frame.maxY - 0.5)))
    }

    func testTabsStayCompactInWidePanesAndScrollInNarrowPanes() {
        XCTAssertEqual(Theme.paneTabWidth(available: 360, count: 2), 180)
        XCTAssertEqual(Theme.paneTabWidth(available: 300, count: 1), 196)
        XCTAssertEqual(Theme.paneTabWidth(available: 800, count: 2), 196)
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
