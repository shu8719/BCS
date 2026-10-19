import XCTest
@testable import BCS

final class ContactFieldTests: XCTestCase {
    func testStringLiteralHasNoReview() {
        let f: ContactField = "A"
        XCTAssertEqual(f.value, "A")
        XCTAssertNil(f.rawValue)
        XCTAssertFalse(f.needsReview)
    }

    func testDecodesBareString() throws {
        let f = try JSONDecoder().decode(ContactField.self, from: Data("\"John\"".utf8))
        XCTAssertEqual(f.value, "John")
        XCTAssertNil(f.reviewReason)
    }

    func testDecodesObject() throws {
        let json = #"{"value":"+1 407-555-0173","rawValue":"D: 407-555.0173","reviewReason":"normalized"}"#
        let f = try JSONDecoder().decode(ContactField.self, from: Data(json.utf8))
        XCTAssertEqual(f.value, "+1 407-555-0173")
        XCTAssertEqual(f.rawValue, "D: 407-555.0173")
        XCTAssertEqual(f.reviewReason, .normalized)
        XCTAssertTrue(f.needsReview)
    }

    func testMarkReviewedClearsReason() {
        var f = ContactField("x", rawValue: "y", reviewReason: .missing)
        f.markReviewed()
        XCTAssertFalse(f.needsReview)
        XCTAssertEqual(f.rawValue, "y")   // the raw text is kept for the record
    }
}
