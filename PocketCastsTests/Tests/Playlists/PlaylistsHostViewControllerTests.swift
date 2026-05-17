import XCTest
@testable import podcasts

final class PlaylistsHostViewControllerTests: XCTestCase {

    func testDefaultsToPlaylistSegment() {
        let host = PlaylistsHostViewController()
        host.loadViewIfNeeded()
        XCTAssertNotNil(host.playlistsViewController, "Playlist child should be loaded by default")
    }

    func testSelectUpNextSwapsChild() {
        let host = PlaylistsHostViewController()
        host.loadViewIfNeeded()
        host.selectUpNext()
        XCTAssertTrue(host.children.first is UpNextViewController,
                      "selectUpNext should make UpNextViewController the visible child")
    }

    func testSelectPlaylistRestoresPlaylistChild() {
        let host = PlaylistsHostViewController()
        host.loadViewIfNeeded()
        host.selectUpNext()
        host.selectPlaylist()
        XCTAssertTrue(host.children.first is PlaylistsViewController,
                      "selectPlaylist should restore PlaylistsViewController as visible child")
    }

    func testTitleViewBoldsActiveSegment() {
        let host = PlaylistsHostViewController()
        host.loadViewIfNeeded()
        let titleView = host.navigationItem.titleView as? SegmentedTitleView
        XCTAssertNotNil(titleView, "Host should install SegmentedTitleView as navigationItem.titleView")
        XCTAssertEqual(titleView?.activeSegment, .playlists, "Default active segment is .playlists")
        host.selectUpNext()
        XCTAssertEqual(titleView?.activeSegment, .upNext, "selectUpNext updates titleView active segment")
    }

    func testNavBarButtonsMirrorActiveChild() {
        let host = PlaylistsHostViewController()
        host.loadViewIfNeeded()
        // After loadViewIfNeeded the playlists child viewDidLoad has run; right button is the add-playlist '+'
        XCTAssertNotNil(host.navigationItem.rightBarButtonItem, "Host should mirror Playlists right bar button after viewDidLoad")
        let playlistsRightButton = host.navigationItem.rightBarButtonItem

        // Swap to UpNext — empty queue means no Select button, so right button becomes nil.
        host.selectUpNext()
        XCTAssertNotEqual(host.navigationItem.rightBarButtonItem, playlistsRightButton,
                          "Host right bar button should change after switching to Up Next segment")
        XCTAssertNil(host.navigationItem.rightBarButtonItem,
                     "Host right bar button should be nil when Up Next queue is empty")

        // Swap back to Playlists — the Playlists '+' button must be re-applied (Bug 1 regression guard).
        host.selectPlaylist()
        XCTAssertNotNil(host.navigationItem.rightBarButtonItem,
                        "Host right bar button should be restored after switching back to Playlists")
    }
}
