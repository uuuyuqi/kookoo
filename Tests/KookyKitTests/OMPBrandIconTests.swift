import AppKit
import XCTest
@testable import KookyKit

@MainActor
final class OMPBrandIconTests: XCTestCase {
    func testBundledOMPUsesWhiteBackingAndPreservesColoredMark() throws {
        let url = try XCTUnwrap(bundleResourceURL(name: "omp", ext: "png", subdirectory: "Icons"))
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: url)))
        XCTAssertEqual(bitmap.pixelsWide, 640)
        XCTAssertEqual(bitmap.pixelsHigh, 640)
        let background = try XCTUnwrap(bitmap.colorAt(x: 320, y: 80)?.usingColorSpace(.deviceRGB))
        XCTAssertGreaterThan(background.redComponent, 0.99)
        XCTAssertGreaterThan(background.greenComponent, 0.99)
        XCTAssertGreaterThan(background.blueComponent, 0.99)
        XCTAssertGreaterThan(background.alphaComponent, 0.99)
        let mark = try XCTUnwrap(bitmap.colorAt(x: 320, y: 200)?.usingColorSpace(.deviceRGB))
        XCTAssertGreaterThan(mark.redComponent, mark.greenComponent)
        XCTAssertGreaterThan(mark.blueComponent, mark.greenComponent)
        let corner = try XCTUnwrap(bitmap.colorAt(x: 0, y: 0))
        XCTAssertLessThan(corner.alphaComponent, 0.01)
        XCTAssertFalse(AgentIcon.isMonochrome("omp"), "Keep brand colors on both themes")
    }
}
