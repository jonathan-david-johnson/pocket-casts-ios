import XCTest
@testable import podcasts

final class RadioFavoritesSeederTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.radioFavoritesSeededM7)
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.radioFavoritesSeededM6)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.radioFavoritesSeededM7)
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.radioFavoritesSeededM6)
        super.tearDown()
    }

    func testNoOpsWhenSignedOut() {
        // Precondition: signed-out (tests run without a Supabase user).
        // Run seeder. Flag must remain unset.
        RadioFavoritesSeeder.seedIfNeeded()
        XCTAssertFalse(UserDefaults.standard.bool(forKey: Constants.UserDefaults.radioFavoritesSeededM7),
                       "Flag must stay unset when no user is signed in")
    }

    func testIdempotentWhenFlagAlreadySet() {
        UserDefaults.standard.set(true, forKey: Constants.UserDefaults.radioFavoritesSeededM7)
        // Should return early without touching anything.
        RadioFavoritesSeeder.seedIfNeeded()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: Constants.UserDefaults.radioFavoritesSeededM7))
    }

    func testCuratedStationsWithSeedFlag() {
        // Sanity: at least KCRW, KEXP, and NPR are flagged seedAsFavorite.
        let seeded = CuratedStationsLoader.load().filter { $0.seedAsFavorite == true }
        let ids = Set(seeded.map { $0.id })
        XCTAssertTrue(ids.contains("kcrw_eclectic_24"))
        XCTAssertTrue(ids.contains("kexp"))
        XCTAssertTrue(ids.contains("npr_hourly"))
    }

    func testSeederUsesUUIDNotGroupId() {
        let curated = CuratedStationsLoader.load().filter { $0.seedAsFavorite == true }
        let uuids = curated.map { $0.defaultSeedUUID }
        XCTAssertTrue(uuids.contains("6238f5e8-a9ee-4c88-9713-2d1ab4112ac9"), "KCRW Eclectic 24 AAC must be the default seed UUID")
        XCTAssertTrue(uuids.contains("445cbb3a-1c4e-49aa-a268-f5b6acfa8f2e"), "KEXP AAC 160k must be the default seed UUID")
        XCTAssertTrue(uuids.contains("a5314180-7573-4b46-aafc-51ed2d5b9e71"), "NPR Newscast must be the default seed UUID")
    }
}
