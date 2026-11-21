import XCTest
@testable import KookyKit

final class AppIconPaginationTests: XCTestCase {
    private let choices = AppIconChoice.all

    func testCatalogUsesFourPagesWithoutDuplicatesOrGaps() {
        var pagination = AppIconPagination(choiceCount: choices.count, selectedIndex: 0)
        XCTAssertEqual(pagination.pageCount, 4)
        XCTAssertFalse(pagination.canGoBack)
        pagination.goBack()
        XCTAssertEqual(pagination.pageNumber, 1)

        var visited: [String] = []
        let pageSizes = [16, 16, 16, 13]
        for (index, size) in pageSizes.enumerated() {
            XCTAssertEqual(pagination.pageNumber, index + 1)
            XCTAssertEqual(pagination.visibleRange.count, size)
            visited += choices[pagination.visibleRange].map(\.id)
            pagination.goForward()
        }
        XCTAssertEqual(visited, choices.map(\.id))
        XCTAssertEqual(pagination.pageNumber, 4)
        XCTAssertFalse(pagination.canGoForward)

        pagination.goBack()
        XCTAssertEqual(pagination.pageNumber, 3)
        XCTAssertEqual(pagination.visibleRange, 32..<48)
    }

    func testInitialPageContainsTheSavedIcon() throws {
        for (id, expectedPage) in [("default", 1), ("16-ocean", 2), ("review-12", 3), ("review-40", 4)] {
            let index = try XCTUnwrap(choices.firstIndex { $0.id == id })
            let pagination = AppIconPagination(choiceCount: choices.count, selectedIndex: index)
            XCTAssertEqual(pagination.pageNumber, expectedPage, id)
            XCTAssertTrue(pagination.visibleRange.contains(index), id)
        }
    }

    func testMissingSelectionFallsBackToFirstPage() {
        let unknown = AppIconPagination(choiceCount: choices.count, selectedIndex: nil)
        XCTAssertEqual(unknown.visibleRange, 0..<16)
        let empty = AppIconPagination(choiceCount: 0, selectedIndex: nil)
        XCTAssertTrue(empty.visibleRange.isEmpty)
        XCTAssertFalse(empty.canGoForward)
    }
}
