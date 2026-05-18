import XCTest
@testable import podcasts

final class RadioBrowserEnhancementTests: XCTestCase {

    func testKCRWUUIDPicksUpEnhancement() {
        let browser = RadioBrowserStation(
            stationuuid: "6238f5e8-a9ee-4c88-9713-2d1ab4112ac9",
            name: "KCRW ECLECTIC 24 (AAC)",
            url: "https://streams.kcrw.com/e24_aac",
            url_resolved: "https://streams.kcrw.com/e24_aac",
            favicon: "https://example.com/favicon.png",
            country: "United States",
            bitrate: 256,
            codec: "AAC"
        )
        let station = browser.toRadioStation()
        XCTAssertEqual(station.logoAsset, "kcrw_logo")
        XCTAssertEqual(station.tracklistUrl, "https://tracklist-api.kcrw.com/Music/all/1?page_size=10")
    }

    func testKCRWEnhancementOverridesDisplayName() {
        let browser = RadioBrowserStation(
            stationuuid: "6238f5e8-a9ee-4c88-9713-2d1ab4112ac9",
            name: "KCRW ECLECTIC 24 (AAC)",
            url_resolved: "https://streams.kcrw.com/e24_aac"
        )
        let station = browser.toRadioStation()
        XCTAssertEqual(station.displayableTitle(), "KCRW Eclectic 24")
    }

    func testUnknownUUIDProducesPlainStation() {
        let browser = RadioBrowserStation(
            stationuuid: "ffffffff-ffff-ffff-ffff-ffffffffffff",
            name: "Some Random Station",
            url: "https://example.com/stream.mp3",
            url_resolved: "https://example.com/stream.mp3",
            favicon: nil,
            country: nil,
            bitrate: 128,
            codec: "MP3"
        )
        let station = browser.toRadioStation()
        XCTAssertNil(station.logoAsset)
        XCTAssertNil(station.tracklistUrl)
    }
}
