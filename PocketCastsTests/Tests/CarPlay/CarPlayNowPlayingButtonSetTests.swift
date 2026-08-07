import XCTest
@testable import podcasts

class CarPlayNowPlayingButtonSetTests: XCTestCase {
    func testPodcastButtonsUnchanged() {
        let buttons = CarPlayNowPlayingButtonSet.buttons(
            isLiveRadio: false,
            canMute: false,
            isMuted: false,
            isFavorite: false,
            chapterCount: 0,
            isStarred: false
        )

        XCTAssertEqual(buttons, [.markAsPlayed, .playbackRate, .star(filled: false)])
    }

    func testPodcastWithChapters() {
        let buttons = CarPlayNowPlayingButtonSet.buttons(
            isLiveRadio: false,
            canMute: false,
            isMuted: false,
            isFavorite: false,
            chapterCount: 5,
            isStarred: false
        )

        XCTAssertEqual(buttons, [.markAsPlayed, .playbackRate, .chapters, .star(filled: false)])
    }

    func testPodcastStarredReflectsState() {
        let buttons = CarPlayNowPlayingButtonSet.buttons(
            isLiveRadio: false,
            canMute: false,
            isMuted: false,
            isFavorite: false,
            chapterCount: 0,
            isStarred: true
        )

        XCTAssertEqual(buttons, [.markAsPlayed, .playbackRate, .star(filled: true)])
    }

    func testRadioNeverShowsMarkAsPlayed() {
        let buttons = CarPlayNowPlayingButtonSet.buttons(
            isLiveRadio: true,
            canMute: true,
            isMuted: false,
            isFavorite: false,
            chapterCount: 5,
            isStarred: true
        )

        XCTAssertFalse(buttons.contains(.markAsPlayed))
        XCTAssertFalse(buttons.contains(.playbackRate))
        XCTAssertFalse(buttons.contains(.star(filled: true)))
        XCTAssertFalse(buttons.contains(.star(filled: false)))
    }

    func testRadioSeekableOmitsMute() {
        let buttons = CarPlayNowPlayingButtonSet.buttons(
            isLiveRadio: true,
            canMute: false,
            isMuted: false,
            isFavorite: false,
            chapterCount: 0,
            isStarred: false
        )

        XCTAssertEqual(buttons, [.favorite(isFavorite: false)])
    }

    func testRadioUnseekableShowsMute() {
        let buttons = CarPlayNowPlayingButtonSet.buttons(
            isLiveRadio: true,
            canMute: true,
            isMuted: true,
            isFavorite: false,
            chapterCount: 0,
            isStarred: false
        )

        XCTAssertEqual(buttons, [.mute(muted: true), .favorite(isFavorite: false)])
    }

    func testUpNextAndAlbumArtistDisabledForRadio() {
        XCTAssertFalse(CarPlayNowPlayingButtonSet.showsUpNextButton(isLiveRadio: true))
        XCTAssertFalse(CarPlayNowPlayingButtonSet.showsAlbumArtistButton(isLiveRadio: true))
        XCTAssertTrue(CarPlayNowPlayingButtonSet.showsUpNextButton(isLiveRadio: false))
        XCTAssertTrue(CarPlayNowPlayingButtonSet.showsAlbumArtistButton(isLiveRadio: false))
    }
}
