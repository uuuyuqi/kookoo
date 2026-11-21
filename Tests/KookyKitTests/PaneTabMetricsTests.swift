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

    func testCloseTargetDoesNotShrinkAndTabFitsHeader() {
        XCTAssertGreaterThanOrEqual(Theme.paneTabCloseButtonSize, 20)
        XCTAssertLessThanOrEqual(
            Theme.paneTabCloseButtonSize + 2 * Theme.paneTabVerticalPadding,
            Theme.paneTabBarHeight - 6
        )
    }

    func testAttachedOutlineHasFlushFirstTabAndReverseFeet() {
        let rect = CGRect(x: 0, y: 0, width: 104, height: 35)
        let first = AttachedTabOutline(flushLeading: true, foot: 4, cornerRadius: 6, lineWidth: 1)
        let inner = AttachedTabOutline(flushLeading: false, foot: 4, cornerRadius: 6, lineWidth: 1)
        XCTAssertTrue(first.fillShape.path(in: rect).contains(CGPoint(x: 0.25, y: 10)))
        XCTAssertFalse(inner.fillShape.path(in: rect).contains(CGPoint(x: 0.25, y: 10)))
        for shape in [first, inner] {
            let fill = shape.fillShape.path(in: rect)
            XCTAssertFalse(fill.contains(CGPoint(x: 102, y: 33)))
            XCTAssertTrue(fill.contains(CGPoint(x: 102, y: 34.4)))
            XCTAssertTrue(fill.contains(CGPoint(x: 50, y: 34.75)))
            XCTAssertEqual(shape.path(in: rect).boundingRect.maxY, 34.5, accuracy: 0.001)
        }
        XCTAssertTrue(inner.fillShape.path(in: rect).contains(CGPoint(x: 2, y: 34.4)))
    }
}
