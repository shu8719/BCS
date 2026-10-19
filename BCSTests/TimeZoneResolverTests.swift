import XCTest
@testable import BCS

final class TimeZoneResolverTests: XCTestCase {
    private var resolver: TimeZoneResolver { repoTimeZoneResolver() }

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
        let db = repoTimeZoneDatabases()
        XCTAssertEqual(db.zip.timeZoneIdentifier(for: "92121"), "America/Los_Angeles")
        XCTAssertEqual(db.zip.timeZoneIdentifier(for: "32826"), "America/New_York")
        XCTAssertEqual(db.area.timeZoneIdentifier(for: "407"), "America/New_York")
        XCTAssertEqual(db.area.timeZoneIdentifier(for: "510"), "America/Los_Angeles")
        XCTAssertGreaterThan(db.zip.entryCount, 30_000)
    }

    func testResolvesRealCardsPreferringZipAfterStateCode() {
        var amazon = BusinessCard()
        amazon.address = "10300 Harbor View Dr, Ste 200, San Diego, CA 92121 USA"
        amazon.phones = [LabeledNumber(label: .mobile, number: "+1 510-555-0147")]
        let a = resolver.resolve(for: amazon)
        XCTAssertEqual(a?.zone, .pst)
        XCTAssertEqual(a?.identifier, "America/Los_Angeles")
        XCTAssertEqual(a?.source, .zip("92121"))   // not the street number 10300
        XCTAssertEqual(a?.conflict, false)

        var lonestar = BusinessCard()
        lonestar.address = "12234 Research Blvd / Bldg A, Austin, TX 78753"
        lonestar.phones = [LabeledNumber(label: .unknown, number: "+1 512-555-0129")]
        XCTAssertEqual(resolver.resolve(for: lonestar)?.zone, .cst)
        XCTAssertEqual(resolver.resolve(for: lonestar)?.source, .zip("78753"))

        var northwind = BusinessCard()
        northwind.address = "12889 Lakeside Drive / Orlando, FL 32826"
        northwind.phones = [LabeledNumber(label: .direct, number: "+1 407-555-0173")]
        XCTAssertEqual(resolver.resolve(for: northwind)?.zone, .est)
        XCTAssertEqual(resolver.resolve(for: northwind)?.source, .zip("32826"))
    }

    func testFallsBackToAreaCodeWhenAddressHasNoZip() {
        var card = BusinessCard()
        card.address = "Market Street, San Francisco, CA, USA"
        card.phones = [LabeledNumber(label: .main, number: "+1 415-555-0132")]
        let r = resolver.resolve(for: card)
        XCTAssertEqual(r?.zone, .pst)
        XCTAssertEqual(r?.source, .areaCode("415"))
        XCTAssertEqual(r?.conflict, false)
    }

    func testFlagsConflictWhenZipAndAreaCodeDisagree() {
        var card = BusinessCard()
        card.address = "1 Main St, Reno, NV 89501"                       // PST
        card.phones = [LabeledNumber(label: .main, number: "+1 212-555-0100")]  // EST
        let r = resolver.resolve(for: card)
        XCTAssertEqual(r?.zone, .pst)              // ZIP wins
        XCTAssertEqual(r?.source, .zip("89501"))
        XCTAssertEqual(r?.conflict, true)
    }

    func testNoConflictWhenOnlyOneSourceResolves() {
        var card = BusinessCard()
        card.address = "1 Main St, Reno, NV 89501"
        XCTAssertEqual(resolver.resolve(for: card)?.conflict, false)
    }

    func testUSAddressDetection() {
        XCTAssertTrue(TimeZoneResolver.looksLikeUSAddress("123 Main St, San Jose, CA 95110", phones: []))
        XCTAssertTrue(TimeZoneResolver.looksLikeUSAddress("1 Infinite Loop, Cupertino, CA 95014, USA", phones: []))
        XCTAssertTrue(TimeZoneResolver.looksLikeUSAddress("Somewhere", phones: [LabeledNumber(label: .main, number: "+1 408-555-1234")]))
        XCTAssertFalse(TimeZoneResolver.looksLikeUSAddress("Hauptstraße 10, 80331 München, DE", phones: []))
        XCTAssertFalse(TimeZoneResolver.looksLikeUSAddress("12 Susan Street, Hi Valley 12345", phones: []))
        XCTAssertFalse(TimeZoneResolver.looksLikeUSAddress("東京都港区芝公園4-2-8", phones: []))
    }

    func testStaleTimeZoneIsClearedWhenAddressNoLongerResolves() {
        var card = BusinessCard()
        card.address = "東京都港区芝公園4-2-8"
        card.timeZone = .pst
        card.timeZoneId = "America/Los_Angeles"
        card.timeZoneSource = .zip("95110")
        let updates = resolver.resolveUpdates(for: [card])
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates.first?.cardID, card.id)
        XCTAssertNil(updates.first?.resolution)
    }

    func testCardWithoutTimeZoneAndNonUSAddressNeedsNoUpdate() {
        var card = BusinessCard()
        card.address = "東京都港区芝公園4-2-8"
        XCTAssertTrue(resolver.resolveUpdates(for: [card]).isEmpty)
    }

    func testSkipsCardsAlreadyResolvedFromSameSource() {
        var card = BusinessCard()
        card.address = "10300 Harbor View Dr, San Diego, CA 92121 USA"
        card.timeZone = .pst
        card.timeZoneId = "America/Los_Angeles"
        card.timeZoneSource = .zip("92121")
        XCTAssertTrue(resolver.resolveUpdates(for: [card]).isEmpty)

        card.timeZoneSource = .areaCode("510")   // previously resolved from a weaker source
        XCTAssertEqual(resolver.resolveUpdates(for: [card]).first?.resolution?.source, .zip("92121"))
    }
}
