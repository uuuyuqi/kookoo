import XCTest
@testable import KookyKit

@MainActor
final class PaneCardStyleTests: XCTestCase {
    func testRestoredPaneDoesNotAnimate() {
        let pane = Pane()
        XCTAssertFalse(pane.consumeInsertionAnimation())
    }

    func testNewSplitAnimatesOnlyOnceWithoutAnimatingExistingSibling() throws {
        let store = makeTestStore()
        let workspace = store.workspaces[0]
        let original = try XCTUnwrap(workspace.root.firstPane)
        let added = try XCTUnwrap(store.splitPane(original, orientation: .horizontal, in: workspace))
        XCTAssertFalse(original.consumeInsertionAnimation())
        XCTAssertTrue(added.consumeInsertionAnimation())
        XCTAssertFalse(added.consumeInsertionAnimation(), "Reparenting/restoring visibility must not replay entrance")
        XCTAssertEqual(workspace.activePaneId, added.id)
    }

    func testReducedMotionSkipsEntrance() {
        XCTAssertTrue(PaneCardStyle.animatesInsertion(pending: true, reduceMotion: false))
        XCTAssertFalse(PaneCardStyle.animatesInsertion(pending: true, reduceMotion: true))
        XCTAssertFalse(PaneCardStyle.animatesInsertion(pending: false, reduceMotion: false))
    }

    func testCardInsetsPreserveTerminalContentInset() {
        XCTAssertEqual(PaneCardStyle.inset + PaneCardStyle.terminalInset, 8)
        XCTAssertEqual(2 * PaneCardStyle.inset + KookyWindowLayout.separatorWidth, 7)
    }

    func testZoomTargetsClickedPaneAndRestoresLayout() throws {
        let store = makeTestStore()
        let workspace = store.workspaces[0]
        let original = try XCTUnwrap(workspace.root.firstPane)
        let added = try XCTUnwrap(store.splitPane(original, orientation: .horizontal, in: workspace))
        XCTAssertEqual(workspace.activePaneId, added.id)
        store.toggleZoom(in: workspace, paneId: original.id)
        XCTAssertTrue(workspace.isZoomed(original.id))
        store.toggleZoom(in: workspace, paneId: original.id)
        XCTAssertNil(workspace.zoomedPaneId)
        XCTAssertEqual(workspace.root.allPanes.count, 2)
    }
}
