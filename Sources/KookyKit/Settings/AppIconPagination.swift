struct AppIconPagination {
    static let pageSize = 16

    private let choiceCount: Int
    private(set) var pageIndex: Int

    init(choiceCount: Int, selectedIndex: Int?) {
        self.choiceCount = choiceCount
        if let selectedIndex, (0..<choiceCount).contains(selectedIndex) {
            pageIndex = selectedIndex / Self.pageSize
        } else {
            pageIndex = 0
        }
    }

    var pageNumber: Int { pageIndex + 1 }
    var pageCount: Int { max(1, (choiceCount + Self.pageSize - 1) / Self.pageSize) }
    var canGoBack: Bool { pageIndex > 0 }
    var canGoForward: Bool { pageNumber < pageCount }

    var visibleRange: Range<Int> {
        let start = pageIndex * Self.pageSize
        return start..<min(start + Self.pageSize, choiceCount)
    }

    mutating func goBack() {
        if canGoBack { pageIndex -= 1 }
    }

    mutating func goForward() {
        if canGoForward { pageIndex += 1 }
    }
}
