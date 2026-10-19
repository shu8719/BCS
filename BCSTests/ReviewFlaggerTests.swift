import XCTest
@testable import BCS

final class ReviewFlaggerTests: XCTestCase {
    func testReformattedPhoneKeepsRawButIsNotFlagged() {
        var card = BusinessCard()
        card.name = "A"; card.company = "B"
        card.phones = [LabeledNumber(label: .direct, number: "D: 407-555.0173"),
                       LabeledNumber(label: .main, number: "(512) 555-0187")]
        ReviewFlagger.apply(to: &card)
        XCTAssertEqual(card.phones[0].number, "+1 407-555-0173")
        XCTAssertEqual(card.phones[0].field.rawValue, "D: 407-555.0173")
        XCTAssertNil(card.phones[0].field.reviewReason)       // separators / +1 only: no review
        XCTAssertEqual(card.phones[1].number, "+1 512-555-0187")
        XCTAssertNil(card.phones[1].field.reviewReason)
        XCTAssertEqual(card.phones[0].label, .direct)
    }

    func testWrongDigitCountIsFlaggedMalformed() {
        var card = BusinessCard()
        card.name = "A"; card.company = "B"
        card.phones = [LabeledNumber(label: .main, number: "408-555-123"),        // digit missing
                       LabeledNumber(label: .main, number: "408-555-12345")]      // extra digit
        ReviewFlagger.apply(to: &card)
        XCTAssertEqual(card.phones[0].number, "408-555-123")                     // left as read
        XCTAssertEqual(card.phones[0].field.reviewReason, .malformed)
        XCTAssertEqual(card.phones[1].field.reviewReason, .malformed)
    }

    func testInternationalAndExtensionNumbersAreLeftAlone() {
        var card = BusinessCard()
        card.name = "A"; card.company = "B"
        card.phones = [LabeledNumber(label: .main, number: "+81 3-1234-5678"),
                       LabeledNumber(label: .main, number: "408-555-1234 x 102")]
        ReviewFlagger.apply(to: &card)
        XCTAssertEqual(card.phones[0].number, "+81 3-1234-5678")
        XCTAssertNil(card.phones[0].field.reviewReason)
        XCTAssertEqual(card.phones[1].number, "408-555-1234 x 102")
        XCTAssertNil(card.phones[1].field.reviewReason)
    }

    func testAlreadyNormalizedPhoneIsNotFlagged() {
        var card = BusinessCard()
        card.name = "A"; card.company = "B"
        card.phones = [LabeledNumber(label: .main, number: "+1 407-555-0173")]
        ReviewFlagger.apply(to: &card)
        XCTAssertNil(card.phones[0].field.rawValue)
        XCTAssertFalse(card.phones[0].field.needsReview)
    }

    func testEmptyNameCompanyAndAddressAreFlaggedMissing() {
        var card = BusinessCard()
        ReviewFlagger.apply(to: &card)
        XCTAssertEqual(card.name.reviewReason, .missing)
        XCTAssertEqual(card.company.reviewReason, .missing)
        XCTAssertEqual(card.address.reviewReason, .missing)
        XCTAssertNil(card.email.reviewReason)    // e-mail is optional on a card
        XCTAssertEqual(card.reviewCount, 3)
    }

    func testParserAppliesFlags() {
        let card = CardParser().parse(items: sampleUSCardItems())
        XCTAssertEqual(card.phones.first?.number, "+1 408-555-1234")
        XCTAssertEqual(card.phones.first?.field.rawValue, "TEL: 408-555-1234")
        XCTAssertFalse(card.phones.first?.field.needsReview ?? true)
        XCTAssertFalse(card.name.needsReview)
        XCTAssertFalse(card.company.needsReview)
    }
}
