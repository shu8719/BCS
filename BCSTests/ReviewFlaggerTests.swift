import XCTest
@testable import BCS

final class ReviewFlaggerTests: XCTestCase {
    func testNormalizedPhoneKeepsRawAndFlags() {
        var card = BusinessCard()
        card.name = "A"; card.company = "B"
        card.phones = [LabeledNumber(label: .direct, number: "D: 407-555.0173")]
        ReviewFlagger.apply(to: &card)
        XCTAssertEqual(card.phones[0].number, "+1 407-555-0173")
        XCTAssertEqual(card.phones[0].field.rawValue, "D: 407-555.0173")
        XCTAssertEqual(card.phones[0].field.reviewReason, .normalized)
        XCTAssertEqual(card.phones[0].label, .direct)
    }

    func testAlreadyNormalizedPhoneIsNotFlagged() {
        var card = BusinessCard()
        card.name = "A"; card.company = "B"
        card.phones = [LabeledNumber(label: .main, number: "+1 407-555-0173")]
        ReviewFlagger.apply(to: &card)
        XCTAssertNil(card.phones[0].field.rawValue)
        XCTAssertFalse(card.phones[0].field.needsReview)
    }

    func testEmptyNameAndCompanyAreFlaggedMissing() {
        var card = BusinessCard()
        ReviewFlagger.apply(to: &card)
        XCTAssertEqual(card.name.reviewReason, .missing)
        XCTAssertEqual(card.company.reviewReason, .missing)
        XCTAssertNil(card.email.reviewReason)
        XCTAssertEqual(card.reviewCount, 2)
    }

    func testParserAppliesFlags() {
        let card = CardParser().parse(items: sampleUSCardItems())
        XCTAssertEqual(card.phones.first?.number, "+1 408-555-1234")
        XCTAssertEqual(card.phones.first?.field.rawValue, "TEL: 408-555-1234")
        XCTAssertFalse(card.name.needsReview)
        XCTAssertFalse(card.company.needsReview)
    }
}
