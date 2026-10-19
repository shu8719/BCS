import XCTest
@testable import BCS

final class BusinessCardCodableTests: XCTestCase {
    private let v1JSON = """
    {"id":"8C8D5B3A-6D1E-4F3E-9D6B-1F2E3D4C5B6A","name":"John Smith","company":"ACME Inc.",
     "phones":[{"id":"1C8D5B3A-6D1E-4F3E-9D6B-1F2E3D4C5B6A","label":"main","number":"TEL: 408-555-1234"}],
     "email":"john@acme.com","address":"123 Main St, San Jose, CA 95110",
     "timeZoneCode":"PST","timeZoneId":"America/Los_Angeles","timeZoneSourceAddress":"95110"}
    """

    func testDecodesV1CardJSON() throws {
        let card = try JSONDecoder().decode(BusinessCard.self, from: Data(v1JSON.utf8))
        XCTAssertEqual(card.name.value, "John Smith")
        XCTAssertEqual(card.company.value, "ACME Inc.")
        XCTAssertEqual(card.phones.count, 1)
        XCTAssertEqual(card.phones[0].label, .main)
        XCTAssertEqual(card.phones[0].number, "TEL: 408-555-1234")
        XCTAssertEqual(card.email.value, "john@acme.com")
        XCTAssertEqual(card.timeZone, .pst)
        XCTAssertEqual(card.timeZoneId, "America/Los_Angeles")
        XCTAssertEqual(card.timeZoneSource, .zip("95110"))
        XCTAssertEqual(card.scannedAt, .distantPast)
        XCTAssertFalse(card.needsReview)
    }

    func testLegacyAreaCodeSourceKey() throws {
        let json = v1JSON.replacingOccurrences(of: "\"95110\"", with: "\"AC:415\"")
        let card = try JSONDecoder().decode(BusinessCard.self, from: Data(json.utf8))
        XCTAssertEqual(card.timeZoneSource, .areaCode("415"))
        XCTAssertNil(TimeZoneSource(legacySourceKey: ""))
    }

    func testRoundTripsV2() throws {
        var card = BusinessCard()
        card.name = ContactField("", reviewReason: .missing)
        card.company = "ACME"
        card.phones = [LabeledNumber(label: .direct, field: ContactField("+1 407-555-0173", rawValue: "D: 407-555.0173", reviewReason: .normalized))]
        card.email = "a@b.com"
        card.address = ContactField("12889 Lakeside Drive / Orlando, FL 32826", reviewReason: .timeZoneConflict)
        card.timeZone = .est
        card.timeZoneId = "America/New_York"
        card.timeZoneSource = .areaCode("407")
        card.scannedAt = Date(timeIntervalSince1970: 1_792_400_000)

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(BusinessCard.self, from: data)
        XCTAssertEqual(decoded, card)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("timeZoneSourceAddress"))
    }

    func testReviewCountCountsAllFields() {
        var card = BusinessCard()
        card.name = ContactField("", reviewReason: .missing)
        card.phones = [LabeledNumber(label: .main, field: ContactField("+1 408-555-1234", rawValue: "408.555.1234", reviewReason: .normalized)),
                       LabeledNumber(label: .mobile, number: "+1 650-555-0000")]
        XCTAssertEqual(card.reviewCount, 2)
        XCTAssertTrue(card.needsReview)
        card.markAllReviewed()
        XCTAssertEqual(card.reviewCount, 0)
        XCTAssertEqual(card.phones[0].field.rawValue, "408.555.1234")
    }
}
