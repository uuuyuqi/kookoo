import XCTest
@testable import KookyKit

@MainActor
final class LaunchWordmarkTests: XCTestCase {
    func testWorkspaceInsertionClaimIsTransientAndSingleUse() {
        let workspace = Workspace(workingDirectory: URL(fileURLWithPath: "/tmp"), root: PaneNode(pane: Pane()))
        XCTAssertFalse(workspace.consumeInsertionAnimation())
        workspace.insertionAnimationPending = true
        XCTAssertTrue(workspace.consumeInsertionAnimation())
        XCTAssertFalse(workspace.consumeInsertionAnimation())
    }

    func testOnlyOneClaimAcrossSidebarRecreation() {
        let gate = LaunchWordmarkGate()
        XCTAssertEqual(gate.claim(reduceMotion: false, roll: 10), false)
        XCTAssertNil(gate.claim(reduceMotion: false, roll: 0))
    }

    func testReduceMotionConsumesClaimWithoutAnimation() {
        let gate = LaunchWordmarkGate()
        XCTAssertNil(gate.claim(reduceMotion: true, roll: 0))
        XCTAssertNil(gate.claim(reduceMotion: false, roll: 0))
    }

    func testTenOfHundredRollsSelectEasterEgg() {
        let selected = (0..<100).filter {
            LaunchWordmarkGate().claim(reduceMotion: false, roll: $0) == true
        }
        XCTAssertEqual(selected, Array(0..<10))
    }

    func testCollisionSettlesBeforeColorFades() {
        for special in [false, true] {
            let frame = LaunchWordmarkFrame(elapsed: 1.6, easterEgg: special)
            XCTAssertEqual(frame.offset, 0)
            XCTAssertEqual(frame.scale, 1)
            XCTAssertEqual(frame.splitOpacity, 0)
            XCTAssertEqual(frame.colorOpacity, 1)
            let end = LaunchWordmarkFrame(elapsed: 2.9, easterEgg: special)
            XCTAssertEqual(end.splitOpacity, 0)
            XCTAssertEqual(end.colorOpacity, 0)
            XCTAssertEqual(end.offset, 0)
        }
    }

    func testAllTimelineValuesRemainBoundedAndEndAtStaticTitle() {
        for special in [false, true] {
            for tick in -10...400 {
                let frame = LaunchWordmarkFrame(elapsed: Double(tick) / 100, easterEgg: special)
                XCTAssertTrue((0...1).contains(frame.arrivalOpacity))
                XCTAssertTrue((0...1).contains(frame.splitOpacity))
                XCTAssertTrue((0...1).contains(frame.colorOpacity))
                XCTAssertTrue((0.94...1.015).contains(frame.scale))
            }
        }
    }
}
