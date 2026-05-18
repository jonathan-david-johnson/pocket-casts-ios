import XCTest
@testable import podcasts

final class StreamsHostViewControllerTests: XCTestCase {
    func testDefaultsToFavoritesSegment() {
        let host = StreamsHostViewController()
        host.loadViewIfNeeded()
        let titleView = host.navigationItem.titleView as? SegmentedTitleView
        XCTAssertEqual(titleView?.activeSegment, .favorites)
    }

    func testSelectBrowseSwapsChild() {
        let host = StreamsHostViewController()
        host.loadViewIfNeeded()
        host.selectBrowse()
        XCTAssertTrue(host.children.contains { $0 is BrowseViewController })
    }

    func testTitleViewIsSegmentedTitleView() {
        let host = StreamsHostViewController()
        host.loadViewIfNeeded()
        XCTAssertTrue(host.navigationItem.titleView is SegmentedTitleView)
    }
}
