import XCTest
@testable import BCS

final class NameParserTests: XCTestCase {
    private let nameParser = NameParser()
    private let addressParser = AddressParser()

    private func pick(_ lines: [OCRLine], email: String, company: String, address: String = "") -> String {
        nameParser.pickName(
            from: lines,
            email: email,
            company: company,
            address: address,
            looksLikeAddressLine: addressParser.looksLikeAddressLine
        )
    }

    func testSurnameContainingContactSubstringIsAccepted() {
        let lines = [
            ocrLine("Example GmbH",           y: 0.85, height: 0.05),
            ocrLine("Hans Weber",             y: 0.70, height: 0.06),
            ocrLine("Engineering Manager",    y: 0.62),
            ocrLine("hans.weber@example.com", y: 0.30),
        ]
        XCTAssertEqual(pick(lines, email: "hans.weber@example.com", company: "Example GmbH"), "Hans Weber")
    }

    func testSurnameIsNotStrippedByGenericBlocklist() {
        let lines = [
            ocrLine("ACME Inc.",         y: 0.85, height: 0.05),
            ocrLine("Mary Kuiper Jones", y: 0.70, height: 0.06),
            ocrLine("Sales Director",    y: 0.62),
        ]
        XCTAssertEqual(pick(lines, email: "", company: "ACME Inc."), "Mary Kuiper Jones")
    }

    func testJobTitleLineIsNotPickedAsName() {
        let lines = [
            ocrLine("ACME Inc.",            y: 0.85, height: 0.05),
            ocrLine("Vice President, Sales", y: 0.70, height: 0.06),
            ocrLine("Taro Yamada",          y: 0.62, height: 0.04),
        ]
        XCTAssertEqual(pick(lines, email: "", company: "ACME Inc."), "Taro Yamada")
    }
}
