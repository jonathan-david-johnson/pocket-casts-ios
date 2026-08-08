import XCTest
import MediaPlayer
@testable import podcasts

class CarPlayConnectionStateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        CarPlaySceneDelegate.setConnectedForTesting(false)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyAlbumTitle: "Original Album" as NSString]
    }

    override func tearDown() {
        CarPlaySceneDelegate.setConnectedForTesting(false)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        super.tearDown()
    }

    func testDefaultsToDisconnected() {
        XCTAssertFalse(CarPlaySceneDelegate.isConnected)
    }

    func testAlbumTitleWritesWhenDisconnected() {
        NowPlayingHelper.setRadioAlbumTitle("line one")

        XCTAssertEqual(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyAlbumTitle] as? String, "line one")
    }

    func testAlbumTitleSuppressedWhenConnected() {
        CarPlaySceneDelegate.setConnectedForTesting(true)

        NowPlayingHelper.setRadioAlbumTitle("line one")

        XCTAssertEqual(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyAlbumTitle] as? String, "Original Album")
    }
}
