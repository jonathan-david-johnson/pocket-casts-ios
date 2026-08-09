import XCTest
@testable import podcasts

final class RadioArtworkSourceTests: XCTestCase {
    func testBundleAssetWinsOverFavicon() {
        let result = RadioArtworkSource.resolve(logoAsset: "kcrw_logo", faviconUrl: "https://example.com/favicon.ico")
        XCTAssertEqual(result, .bundleAsset("kcrw_logo"))
    }

    func testFaviconUsedWhenNoLogoAsset() {
        let result = RadioArtworkSource.resolve(logoAsset: nil, faviconUrl: "https://example.com/favicon.ico")
        XCTAssertEqual(result, .remote(URL(string: "https://example.com/favicon.ico")!))
    }

    func testPlaceholderWhenNeitherPresent() {
        let result = RadioArtworkSource.resolve(logoAsset: nil, faviconUrl: nil)
        XCTAssertEqual(result, .placeholder)
    }

    func testEmptyStringsTreatedAsAbsent() {
        let result = RadioArtworkSource.resolve(logoAsset: "", faviconUrl: "")
        XCTAssertEqual(result, .placeholder)
    }

    func testWhitespaceOnlyFaviconTreatedAsAbsent() {
        let result = RadioArtworkSource.resolve(logoAsset: nil, faviconUrl: "   ")
        XCTAssertEqual(result, .placeholder)
    }

    func testInvalidFaviconUrlFallsBackToPlaceholder() {
        let result = RadioArtworkSource.resolve(logoAsset: nil, faviconUrl: "not a url")
        XCTAssertEqual(result, .placeholder)
    }

    func testNonHttpSchemeRejected() {
        let result = RadioArtworkSource.resolve(logoAsset: nil, faviconUrl: "ftp://example.com/f.ico")
        XCTAssertEqual(result, .placeholder)
    }

    func testHttpsFaviconAccepted() {
        let result = RadioArtworkSource.resolve(logoAsset: nil, faviconUrl: "https://example.com/f.ico")
        XCTAssertEqual(result, .remote(URL(string: "https://example.com/f.ico")!))
    }
}
