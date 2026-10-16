import XCTest
@testable import BCS

final class AddressParserTests: XCTestCase {
    private let parser = AddressParser()

    func testStreetNamesContainingContactSubstringsAreStillAddresses() {
        XCTAssertTrue(parser.looksLikeAddressLine("123 Webster Avenue"))
        XCTAssertTrue(parser.looksLikeAddressLine("1 Telford Road"))
    }

    func testBarePhoneLinesAreNotAddresses() {
        XCTAssertFalse(parser.looksLikeAddressLine("• 407.555.0162"))
        XCTAssertFalse(parser.looksLikeAddressLine("D 407-555.0173"))
        XCTAssertFalse(parser.looksLikeAddressLine("(512) 555-0129"))
        XCTAssertFalse(parser.looksLikeAddressLine("+1 510 555 0147"))
        XCTAssertTrue(parser.looksLikeAddressLine("12889 Lakeside Drive"))
    }

    func testContactLinesAreNotAddresses() {
        XCTAssertFalse(parser.looksLikeAddressLine("Tel: 408-555-1234"))
        XCTAssertFalse(parser.looksLikeAddressLine("Email: john@example.com"))
        XCTAssertFalse(parser.looksLikeAddressLine("www.example.com"))
    }

    func testMultiLineAddressBlockIsJoined() {
        let lines = [
            ocrLine("ACME Inc.",             y: 0.85, height: 0.05),
            ocrLine("123 Webster Avenue",    y: 0.25),
            ocrLine("Suite 400",             y: 0.21),
            ocrLine("Springfield, IL 62701", y: 0.17),
        ]
        let text = parser.pickAddressBlockInfo(from: lines).text
        XCTAssertTrue(text.contains("123 Webster Avenue"), text)
        XCTAssertTrue(text.contains("IL 62701"), text)
    }
}
