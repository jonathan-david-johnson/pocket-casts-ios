import XCTest
@testable import podcasts

final class SegmentedTitleViewTests: XCTestCase {
    func testDefaultActiveSegment() {
        let v = SegmentedTitleView()
        XCTAssertEqual(v.activeSegment, .playlists)
    }

    func testTapInactiveSegmentFiresCallback() {
        let v = SegmentedTitleView()
        var fired: SegmentedTitleView.Segment?
        v.onSelect = { fired = $0 }
        v.simulateTap(on: .upNext)
        XCTAssertEqual(fired, .upNext)
    }

    func testTapActiveSegmentDoesNotFire() {
        let v = SegmentedTitleView()
        var fired: SegmentedTitleView.Segment?
        v.onSelect = { fired = $0 }
        v.simulateTap(on: .playlists) // already active
        XCTAssertNil(fired)
    }
}
