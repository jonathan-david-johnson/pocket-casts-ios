import XCTest
@testable import podcasts

final class CuratedEnhancementsIndexTests: XCTestCase {

    func testIndexContainsAllCuratedUUIDs() {
        let index = CuratedStationsLoader.enhancementsByUUID
        // KCRW
        XCTAssertNotNil(index["18e31f25-53c8-4213-a1ec-dccc0443a788"])
        XCTAssertNotNil(index["25ff2df8-f8ea-4af8-b283-48ba3bdcaf69"])
        XCTAssertNotNil(index["6238f5e8-a9ee-4c88-9713-2d1ab4112ac9"])
        // KEXP
        XCTAssertNotNil(index["445cbb3a-1c4e-49aa-a268-f5b6acfa8f2e"])
        XCTAssertNotNil(index["399ca326-0f67-4015-a51b-d7ba2bd4ebbe"])
        XCTAssertNotNil(index["a509502d-1ba7-4d51-9791-0be5a7d5ec34"])
        // NPR
        XCTAssertNotNil(index["a5314180-7573-4b46-aafc-51ed2d5b9e71"])
    }

    func testKCRWVariantsShareEnhancement() {
        let index = CuratedStationsLoader.enhancementsByUUID
        let aac = index["6238f5e8-a9ee-4c88-9713-2d1ab4112ac9"]
        let mp3 = index["18e31f25-53c8-4213-a1ec-dccc0443a788"]
        XCTAssertEqual(aac, mp3, "KCRW variants must share the same enhancement object")
        XCTAssertEqual(aac?.logoAsset, "kcrw_logo")
        XCTAssertEqual(aac?.tracklistUrl, "https://tracklist-api.kcrw.com/Music/all/1?page_size=10")
    }

    func testUnknownUUIDReturnsNil() {
        let index = CuratedStationsLoader.enhancementsByUUID
        XCTAssertNil(index["00000000-0000-0000-0000-000000000000"])
    }
}
