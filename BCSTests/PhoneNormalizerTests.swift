import XCTest
@testable import BCS

final class PhoneNormalizerTests: XCTestCase {
    func testFormatsLabeledUSNumber() {
        XCTAssertEqual(PhoneNormalizer.normalizeUS("D: 407-555.0173"), "+1 407-555-0173")
    }

    func testFormatsElevenDigitWithCountryCode() {
        XCTAssertEqual(PhoneNormalizer.normalizeUS("+1 510 555 0147"), "+1 510-555-0147")
    }

    func testKeepsNumbersWithExtensionUntouched() {
        XCTAssertNil(PhoneNormalizer.normalizeUS("408-555-1234 x 102"))
        XCTAssertNil(PhoneNormalizer.normalizeUS("408-555-1234 ext. 5"))
    }

    func testRejectsNonUSLengths() {
        XCTAssertNil(PhoneNormalizer.normalizeUS("03-1234-5678"))      // leading 0 is not a US area code
        XCTAssertNil(PhoneNormalizer.normalizeUS("+44 20 7946 0958"))  // 12 digits
    }

    func testDialableDropsExtensionAndLabels() {
        XCTAssertEqual(PhoneNormalizer.dialable("408-555-1234 x 102"), "4085551234")
        XCTAssertEqual(PhoneNormalizer.dialable("TEL: 408-555-1234 ext. 5"), "4085551234")
        XCTAssertEqual(PhoneNormalizer.dialable("+1 407-555-0173"), "+14075550173")
        XCTAssertEqual(PhoneNormalizer.dialable(""), "")
    }

    func testAlreadyNormalizedIsIdempotent() {
        XCTAssertEqual(PhoneNormalizer.normalizeUS("+1 407-555-0173"), "+1 407-555-0173")
    }
}
