import AppKit
import SwiftUI
import XCTest
@testable import KookyKit

@MainActor
final class SidebarEmptySpaceTests: XCTestCase {
    private func settle() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
    }

    private func click(_ window: NSWindow, at point: NSPoint, count: Int) throws {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try XCTUnwrap(NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil,
                eventNumber: 0, clickCount: count, pressure: type == .leftMouseDown ? 1 : 0
            ))
            window.sendEvent(event)
        }
    }

    func testEmptySpaceCreatesExactlyOneWorkspaceWithoutChangingRowsOrFooter() throws {
        let store = makeTestStore()
        defer { store.terminate() }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 700),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SidebarView(store: store, mode: .full))
        window.orderFront(nil)
        defer { window.close() }
        settle()
        let originalCount = store.workspaces.count

        // Middle of the visibly empty list, far below the first row.
        try click(window, at: NSPoint(x: 100, y: 200), count: 1)
        settle()
        XCTAssertEqual(store.workspaces.count, originalCount)
        try click(window, at: NSPoint(x: 100, y: 200), count: 2)
        settle()
        XCTAssertEqual(store.workspaces.count, originalCount + 1)

        // Repeating the gesture still adds once, not once per mouse event.
        try click(window, at: NSPoint(x: 100, y: 200), count: 1)
        try click(window, at: NSPoint(x: 100, y: 200), count: 2)
        settle()
        XCTAssertEqual(store.workspaces.count, originalCount + 2)

        // Existing workspace row and footer are not new-workspace targets.
        try click(window, at: NSPoint(x: 100, y: 635), count: 1)
        try click(window, at: NSPoint(x: 100, y: 635), count: 2)
        settle()
        XCTAssertEqual(store.workspaces.count, originalCount + 2)
        try click(window, at: NSPoint(x: 100, y: 15), count: 1)
        try click(window, at: NSPoint(x: 100, y: 15), count: 2)
        settle()
        XCTAssertEqual(store.workspaces.count, originalCount + 2)
    }
}
