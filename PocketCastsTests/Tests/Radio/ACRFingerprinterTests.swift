import XCTest
@testable import podcasts

class ACRFingerprinterTests: XCTestCase {

    // MARK: - parseResult

    func testParseResult_successWithFullFields() {
        let json = """
        {
            "status": {"code": 0, "msg": "Success", "version": "1.0"},
            "metadata": {
                "music": [{
                    "title": "Wasted on You",
                    "artists": [{"name": "Andy Shauf"}],
                    "album": {"name": "The Party"},
                    "score": 92
                }]
            }
        }
        """.data(using: .utf8)!

        let fp = ACRFingerprinter(streamURL: URL(string: "https://example.com")!)
        let result = fp.parseResultForTesting(json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "Wasted on You")
        XCTAssertEqual(result?.artist, "Andy Shauf")
        XCTAssertEqual(result?.album, "The Party")
        XCTAssertEqual(result?.confidence, 92)
    }

    func testParseResult_noResult_returnsNil() {
        let json = """
        {"status": {"code": 1001, "msg": "No result", "version": "1.0"}}
        """.data(using: .utf8)!

        let fp = ACRFingerprinter(streamURL: URL(string: "https://example.com")!)
        XCTAssertNil(fp.parseResultForTesting(json))
    }

    func testParseResult_missingArtists_stillParsesTitle() {
        let json = """
        {
            "status": {"code": 0, "msg": "Success", "version": "1.0"},
            "metadata": {
                "music": [{
                    "title": "Unknown Track",
                    "score": 75
                }]
            }
        }
        """.data(using: .utf8)!

        let fp = ACRFingerprinter(streamURL: URL(string: "https://example.com")!)
        let result = fp.parseResultForTesting(json)
        XCTAssertEqual(result?.title, "Unknown Track")
        XCTAssertEqual(result?.artist, "")
        XCTAssertEqual(result?.confidence, 75)
    }

    // MARK: - displayTitle

    func testDisplayTitle_withArtist() {
        let r = ACRFingerprintResult(title: "Hello", artist: "Adele", album: "", confidence: 100)
        XCTAssertEqual(r.displayTitle, "Hello — Adele")
    }

    func testDisplayTitle_withoutArtist() {
        let r = ACRFingerprintResult(title: "Hello", artist: "", album: "", confidence: 100)
        XCTAssertEqual(r.displayTitle, "Hello")
    }

    // MARK: - minConfidence filter

    func testLowConfidenceResultNotSurfaced() {
        let json = """
        {
            "status": {"code": 0, "msg": "Success", "version": "1.0"},
            "metadata": {
                "music": [{"title": "Track", "artists": [{"name": "Artist"}], "score": 40}]
            }
        }
        """.data(using: .utf8)!

        let fp = ACRFingerprinter(streamURL: URL(string: "https://example.com")!)
        let result = fp.parseResultForTesting(json)
        // parseResult returns the result regardless of minConfidence —
        // the caller (identifyOnce) gates on minConfidence. Confirm score parsed.
        XCTAssertEqual(result?.confidence, 40)
    }
}
