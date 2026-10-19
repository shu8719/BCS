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

    func testGarbledLinesAreNotAddresses() {
        XCTAssertFalse(parser.looksLikeAddressLine("1≥PÑ 4100"))
        XCTAssertFalse(parser.looksLikeAddressLine("|||| 4100 ^^"))
        XCTAssertTrue(parser.looksLikeAddressLine("4100 Lakeline Blvd, Suite 210"))   // ordinary punctuation is fine
        XCTAssertTrue(parser.looksLikeAddressLine("Calle Peñón 12, Nuñez"))            // accented letters are fine
    }

    func testGarbledLineIsSkippedAndTheRealAddressKept() {
        let lines = [
            ocrLine("1≥PÑ 4100",               y: 0.29),
            ocrLine("Lakeline Blvd, Suite 210", y: 0.25),
            ocrLine("Austin, TX 78717",         y: 0.21),
        ]
        let text = parser.pickAddressBlockInfo(from: lines).text
        XCTAssertFalse(text.contains("≥"), text)
        XCTAssertTrue(text.contains("Lakeline Blvd"), text)
        XCTAssertTrue(text.contains("TX 78717"), text)
    }

    func testContactLinesAreNotAddresses() {
        XCTAssertFalse(parser.looksLikeAddressLine("Tel: 408-555-1234"))
        XCTAssertFalse(parser.looksLikeAddressLine("Email: john@example.com"))
        XCTAssertFalse(parser.looksLikeAddressLine("www.example.com"))
    }

    func testLeadingAddressLabelIsStripped() {
        let lines = [
            ocrLine("Hanako Sato",          y: 0.70, height: 0.06),
            ocrLine("A 1120 NW Couch St",   y: 0.25),
            ocrLine("Portland, OR 97209",   y: 0.21),
        ]
        let text = parser.pickAddressBlockInfo(from: lines).text
        XCTAssertTrue(text.hasPrefix("1120 NW Couch St"), text)

        let labeled = [ocrLine("Address: 12889 Lakeside Drive", y: 0.25), ocrLine("Orlando, FL 32826", y: 0.21)]
        XCTAssertTrue(parser.pickAddressBlockInfo(from: labeled).text.hasPrefix("12889"), parser.pickAddressBlockInfo(from: labeled).text)
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
