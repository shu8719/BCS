import XCTest
@testable import BCS

final class CardEditLogicTests: XCTestCase {
    // Stored, not computed: phone ids must stay the same between "original" and "draft".
    private let original: BusinessCard = {
        var c = BusinessCard()
        c.name = ContactField("", reviewReason: .missing)
        c.company = "ACME"
        c.phones = [LabeledNumber(label: .direct, field: ContactField("+1 407-555-0173", rawValue: "D: 407-555.0173", reviewReason: .normalized))]
        c.address = ContactField("x", reviewReason: .timeZoneConflict)
        return c
    }()

    func testChangedFieldLosesReviewFlag() {
        var draft = original
        draft.name.value = "David Morgan"
        draft.phones[0].number = "+1 407-531-7314"
        let result = CardEditLogic.applyingEdits(original: original, draft: draft)
        XCTAssertNil(result.name.reviewReason)
        XCTAssertNil(result.phones[0].field.reviewReason)
        XCTAssertEqual(result.phones[0].field.rawValue, "D: 407-555.0173")   // history is kept
        XCTAssertEqual(result.address.reviewReason, .timeZoneConflict)      // untouched
    }

    func testUnchangedFieldKeepsReviewFlag() {
        let result = CardEditLogic.applyingEdits(original: original, draft: original)
        XCTAssertEqual(result.reviewCount, 3)
    }

    func testAddedPhoneHasNoReview() {
        var draft = original
        draft.phones.append(LabeledNumber(label: .unknown, number: "+1 650-555-0000"))
        let result = CardEditLogic.applyingEdits(original: original, draft: draft)
        XCTAssertEqual(result.phones.count, 2)
        XCTAssertFalse(result.phones[1].field.needsReview)
        XCTAssertEqual(result.phones[0].field.reviewReason, .normalized)
    }
}
