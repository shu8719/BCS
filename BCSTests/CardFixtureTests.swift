import XCTest
@testable import BCS

final class CardFixtureTests: XCTestCase {
    func testRoundTripsThroughJSON() throws {
        var expected = CardFixture.Expected()
        expected.name = "John Smith"
        expected.phones = ["408-555-1234"]
        let fixture = CardFixture(
            name: "sample",
            source: .paper,
            items: [CardFixture.Item(text: "John Smith", x: 0.1, y: 0.7, w: 0.3, h: 0.06)],
            expected: expected
        )

        let data = try CardFixture.encode(fixture)
        let decoded = try CardFixture.decode(data)

        XCTAssertEqual(decoded, fixture)
        XCTAssertEqual(decoded.ocrItems.first?.text, "John Smith")
        XCTAssertEqual(decoded.ocrItems.first?.box, CGRect(x: 0.1, y: 0.7, width: 0.3, height: 0.06))
    }

    func testBuildsFromParsedCardWithExpectedPrefilled() {
        var card = BusinessCard()
        card.name = "John Smith"
        card.company = "ACME Inc."
        card.phones = [LabeledNumber(label: .main, number: "TEL: 408-555-1234")]
        card.email = "john@acme.com"
        card.address = "123 Main St, San Jose, CA 95110"

        let fixture = CardFixture(name: "x", source: .image, items: [ocrItem("John Smith", y: 0.7)], card: card, timeZoneCode: "PST")

        XCTAssertEqual(fixture.expected.name, "John Smith")
        XCTAssertEqual(fixture.expected.company, "ACME Inc.")
        XCTAssertEqual(fixture.expected.phones, ["TEL: 408-555-1234"])
        XCTAssertEqual(fixture.expected.email, "john@acme.com")
        XCTAssertEqual(fixture.expected.address, "123 Main St, San Jose, CA 95110")
        XCTAssertEqual(fixture.expected.timeZoneCode, "PST")
        XCTAssertEqual(fixture.items.count, 1)
    }

    func testMissingExpectedFieldsDecodeAsNil() throws {
        let json = """
        {"name":"m","source":"screen","createdAt":"2026-10-16T00:00:00Z","notes":"",
         "items":[],"expected":{"name":"Only Name"}}
        """
        let fixture = try CardFixture.decode(Data(json.utf8))
        XCTAssertEqual(fixture.expected.name, "Only Name")
        XCTAssertNil(fixture.expected.company)
        XCTAssertNil(fixture.expected.phones)
    }
}
