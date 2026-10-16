import XCTest
@testable import BCS

final class TimeZoneResolverTests: XCTestCase {
    private var repoDatabases: (zip: ZipTimeZoneDB, area: AreaCodeTimeZoneDB) { repoTimeZoneDatabases() }

    func testCodeMappingDoesNotDependOnLocaleAbbreviations() {
        XCTAssertEqual(TimeZoneResolver.code(forTimeZoneIdentifier: "America/Los_Angeles"), "PST")
        XCTAssertEqual(TimeZoneResolver.code(forTimeZoneIdentifier: "America/Denver"), "MST")
        XCTAssertEqual(TimeZoneResolver.code(forTimeZoneIdentifier: "America/Phoenix"), "MST")
        XCTAssertEqual(TimeZoneResolver.code(forTimeZoneIdentifier: "America/Chicago"), "CST")
        XCTAssertEqual(TimeZoneResolver.code(forTimeZoneIdentifier: "America/New_York"), "EST")
        XCTAssertEqual(TimeZoneResolver.code(forTimeZoneIdentifier: "America/Indiana/Indianapolis"), "EST")
        XCTAssertNil(TimeZoneResolver.code(forTimeZoneIdentifier: "America/Anchorage"))
        XCTAssertNil(TimeZoneResolver.code(forTimeZoneIdentifier: "America/Puerto_Rico"))
        XCTAssertNil(TimeZoneResolver.code(forTimeZoneIdentifier: "Not/AZone"))
    }

    func testBundledDatabasesLoad() {
        let db = repoDatabases
        XCTAssertEqual(db.zip.timeZoneIdentifier(for: "92121"), "America/Los_Angeles")
        XCTAssertEqual(db.zip.timeZoneIdentifier(for: "32826"), "America/New_York")
        XCTAssertEqual(db.area.timeZoneIdentifier(for: "407"), "America/New_York")
        XCTAssertEqual(db.area.timeZoneIdentifier(for: "510"), "America/Los_Angeles")
        XCTAssertGreaterThan(db.zip.entryCount, 30_000)
    }

    func testResolvesRealCardsPreferringZipAfterStateCode() {
        let db = repoDatabases
        let resolver = TimeZoneResolver(zipDB: db.zip, areaDB: db.area)

        var amazon = BusinessCard()
        amazon.address = "10300 Harbor View Dr, Ste 200, San Diego, CA 92121 USA"
        amazon.phones = [LabeledNumber(label: .mobile, number: "M: +1 510 555 0147")]
        let a = resolver.resolve(for: amazon)
        XCTAssertEqual(a?.meta.code, "PST")
        XCTAssertEqual(a?.sourceKey, "92121")   // not the street number 10300

        var lonestar = BusinessCard()
        lonestar.address = "12234 Research Blvd / Bldg A, Austin, TX 78753"
        lonestar.phones = [LabeledNumber(label: .unknown, number: "(512) 555-0129")]
        let v = resolver.resolve(for: lonestar)
        XCTAssertEqual(v?.meta.code, "CST")
        XCTAssertEqual(v?.sourceKey, "78753")

        var northwind = BusinessCard()
        northwind.address = "12889 Lakeside Drive / Orlando, FL 32826"
        northwind.phones = [LabeledNumber(label: .direct, number: "D: 407-555.0173")]
        let s = resolver.resolve(for: northwind)
        XCTAssertEqual(s?.meta.code, "EST")
        XCTAssertEqual(s?.sourceKey, "32826")
    }

    func testFallsBackToAreaCodeWhenAddressHasNoZip() {
        let db = repoDatabases
        let resolver = TimeZoneResolver(zipDB: db.zip, areaDB: db.area)
        var card = BusinessCard()
        card.address = "Market Street, San Francisco, CA, USA"
        card.phones = [LabeledNumber(label: .main, number: "TEL: 415.555.0132")]
        let r = resolver.resolve(for: card)
        XCTAssertEqual(r?.meta.code, "PST")
        XCTAssertEqual(r?.sourceKey, "AC:415")
    }

    func testStaleTimeZoneIsClearedWhenAddressNoLongerResolves() {
        var card = BusinessCard()
        card.address = "東京都港区芝公園4-2-8"
        card.timeZoneCode = "PST"
        card.timeZoneId = "America/Los_Angeles"
        card.timeZoneSourceAddress = "95110"

        let updates = TimeZoneResolver.resolveUpdates(for: [card])
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates.first?.cardID, card.id)
        XCTAssertEqual(updates.first?.code, "")
        XCTAssertEqual(updates.first?.identifier, "")
        XCTAssertEqual(updates.first?.sourceKey, "")
    }

    func testUSAddressDetection() {
        XCTAssertTrue(TimeZoneResolver.looksLikeUSAddress("123 Main St, San Jose, CA 95110", phones: []))
        XCTAssertTrue(TimeZoneResolver.looksLikeUSAddress("1 Infinite Loop, Cupertino, CA 95014, USA", phones: []))
        XCTAssertTrue(TimeZoneResolver.looksLikeUSAddress("Somewhere", phones: [LabeledNumber(label: .main, number: "+1 408-555-1234")]))

        // "DE" is a state code but is not followed by a ZIP; 80331 alone must not count.
        XCTAssertFalse(TimeZoneResolver.looksLikeUSAddress("Hauptstraße 10, 80331 München, DE", phones: []))
        // "SUSAN" contains "USA" and "Hi" is a state code as a bare token; neither should count.
        XCTAssertFalse(TimeZoneResolver.looksLikeUSAddress("12 Susan Street, Hi Valley 12345", phones: []))
        XCTAssertFalse(TimeZoneResolver.looksLikeUSAddress("東京都港区芝公園4-2-8", phones: []))
    }

    func testCardWithoutTimeZoneAndNonUSAddressNeedsNoUpdate() {
        var card = BusinessCard()
        card.address = "東京都港区芝公園4-2-8"
        XCTAssertTrue(TimeZoneResolver.resolveUpdates(for: [card]).isEmpty)
    }
}
