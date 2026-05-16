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
        let upNextNav = host.children.first as? UINavigationController
        XCTAssertTrue(upNextNav?.viewControllers.first is UpNextViewController,
                      "selectUpNext should make UpNextViewController the visible child")
    }

    func testSelectPlaylistRestoresPlaylistChild() {
        let host = PlaylistsHostViewController()
        host.loadViewIfNeeded()
        host.selectUpNext()
        host.selectPlaylist()
        let nav = host.children.first as? UINavigationController
        XCTAssertTrue(nav?.viewControllers.first is PlaylistsViewController,
                      "selectPlaylist should restore PlaylistsViewController as visible child")
    }
}
