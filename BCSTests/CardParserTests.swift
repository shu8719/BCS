import XCTest
@testable import BCS

final class CardParserTests: XCTestCase {
    func testParsesSimpleUSCard() {
        let card = CardParser().parse(items: sampleUSCardItems())

        XCTAssertEqual(card.name, "John Smith")
        XCTAssertEqual(card.company, "ACME Electronics Inc.")
        XCTAssertEqual(card.email, "john.smith@acme.com")
        XCTAssertEqual(card.phones.map(\.number), ["+1 408-555-1234"])
        XCTAssertTrue(card.address.value.contains("CA 95110"), card.address.value)
    }

    func testSplitsTwoColumnRowIntoSeparateLines() {
        // Real OCR boxes from a two-column card: the name on the left and a phone on the right
        // share the same Y but are separated by a gap wider than the text height.
        let items = [
            ocrItem("DAVID MORGAN",  y: 0.457, height: 0.063, x: 0.050, width: 0.316),
            ocrItem("D 407-555.0173", y: 0.473, height: 0.048, x: 0.509, width: 0.192),
        ]
        let texts = CardParser().buildLines(from: items).map(\.text)
        XCTAssertEqual(texts, ["DAVID MORGAN", "D 407-555.0173"])
    }

    func testKeepsFragmentsOfOneLineTogether() {
        let items = [
            ocrItem("Tel:",         y: 0.40, height: 0.03, x: 0.05, width: 0.06),
            ocrItem("408-555-1234", y: 0.40, height: 0.03, x: 0.12, width: 0.20),
        ]
        let texts = CardParser().buildLines(from: items).map(\.text)
        XCTAssertEqual(texts, ["Tel: 408-555-1234"])
    }

    func testReturnsEmptyCardForNoItems() {
        let card = CardParser().parse(items: [])
        XCTAssertEqual(card.name.value, "")
        XCTAssertEqual(card.company.value, "")
        XCTAssertTrue(card.phones.isEmpty)
        XCTAssertEqual(card.name.reviewReason, .missing)   // spec §4 rule 2
    }
}
