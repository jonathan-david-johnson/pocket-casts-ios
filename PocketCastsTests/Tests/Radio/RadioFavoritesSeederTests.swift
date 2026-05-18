import XCTest
@testable import podcasts

final class RadioFavoritesSeederTests: XCTestCase {

    private let flagKey = Constants.UserDefaults.radioFavoritesSeeded

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: flagKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: flagKey)
        super.tearDown()
    }

    func testNoOpsWhenSignedOut() {
        // Precondition: signed-out (tests run without a Supabase user).
        // Run seeder. Flag must remain unset.
        RadioFavoritesSeeder.seedIfNeeded()
        XCTAssertFalse(UserDefaults.standard.bool(forKey: flagKey),
                       "Flag must stay unset when no user is signed in")
    }

    func testIdempotentWhenFlagAlreadySet() {
        UserDefaults.standard.set(true, forKey: flagKey)
        // Should return early without touching anything.
        RadioFavoritesSeeder.seedIfNeeded()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: flagKey))
    }

    func testCuratedStationsWithSeedFlag() {
        // Sanity: at least KCRW, KEXP, and NPR are flagged seedAsFavorite.
        let seeded = CuratedStationsLoader.load().filter { $0.seedAsFavorite == true }
        let ids = Set(seeded.map { $0.id })
        XCTAssertTrue(ids.contains("kcrw"))
        XCTAssertTrue(ids.contains("kexp"))
        XCTAssertTrue(ids.contains("npr_hourly"))
    }
}
