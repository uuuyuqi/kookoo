import XCTest
@testable import KookyKit

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
}
