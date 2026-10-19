import XCTest
@testable import BCS

final class PhoneParserTests: XCTestCase {
    private let parser = PhoneParser()

    private func digits(_ phones: [LabeledNumber]) -> Set<String> {
        Set(phones.map { $0.number.filter(\.isNumber) })
    }

    func testLabeledTelNumber() {
        let phones = parser.extractPhones(from: [ocrLine("Tel: 408-555-1234", y: 0.4)])
        XCTAssertEqual(phones.count, 1)
        XCTAssertEqual(phones.first?.label, .main)
        XCTAssertEqual(phones.first?.number, "TEL: 408-555-1234")
    }

    func testFaxNumbersAreExcluded() {
        XCTAssertTrue(parser.extractPhones(from: [ocrLine("Fax: 408-555-9999", y: 0.4)]).isEmpty)
        XCTAssertTrue(parser.extractPhones(from: [ocrLine("F: 408-555-9999", y: 0.4)]).isEmpty)
    }

    func testFaxOnAnotherLineDoesNotDropUnlabeledNumbers() {
        let lines = [
            ocrLine("Tel: 408-555-1234", y: 0.50),
            ocrLine("Fax: 408-555-9999", y: 0.45),
            ocrLine("650-555-0000",      y: 0.40),
        ]
        let phones = parser.extractPhonesFromWholeText(lines: lines)
        XCTAssertEqual(digits(phones), ["4085551234", "6505550000"])
    }

    func testFColonInsideAWordIsNotAFaxLabel() {
        let phones = parser.extractPhones(from: [ocrLine("Ref: 650-555-0000", y: 0.4)])
        XCTAssertEqual(digits(phones), ["6505550000"])
    }

    func testStripsPhoneLabelsAndBulletsFromAddressText() {
        let result = parser.extractPhonesFromAddressText("D 407-555.0173 / • 407.555.0162 / 12889 Lakeside Drive / Orlando, FL 32826")
        XCTAssertEqual(result.cleanAddress, "12889 Lakeside Drive / Orlando, FL 32826")
        XCTAssertEqual(digits(result.phones), ["4075550173", "4075550162"])
    }

    func testSingleLetterLabelWithoutColonIsRecognized() {
        let phones = parser.extractPhones(from: [ocrLine("D 407-555.0173", y: 0.4)])
        XCTAssertEqual(phones.count, 1)
        XCTAssertEqual(phones.first?.label, .direct)
        XCTAssertEqual(digits(phones), ["4075550173"])
    }

    func testCellAndOfficeLabels() {
        XCTAssertEqual(parser.extractPhones(from: [ocrLine("C 512-555-0187", y: 0.4)]).first?.label, .mobile)
        XCTAssertEqual(parser.extractPhones(from: [ocrLine("Cell: 512-555-0187", y: 0.4)]).first?.label, .mobile)
        XCTAssertEqual(parser.extractPhones(from: [ocrLine("O 407.555.0162", y: 0.4)]).first?.label, .main)
        XCTAssertEqual(parser.extractPhones(from: [ocrLine("Office: 407.555.0162", y: 0.4)]).first?.label, .main)
    }

    func testDedupeIgnoresCountryCodeAndKeepsTheLabeledOne() {
        let phones = parser.dedupePhones([
            LabeledNumber(label: .unknown, number: "+1 512-555-0187"),
            LabeledNumber(label: .mobile,  number: "M: 512-555-0187"),
            LabeledNumber(label: .unknown, number: "(512) 555-0187"),
        ])
        XCTAssertEqual(phones.count, 1)
        XCTAssertEqual(phones.first?.label, .mobile)
    }

    func testWholeCardDedupesAcrossLinesAndColumns() {
        let lines = [ocrLine("C 512-555-0187", y: 0.5), ocrLine("+1 512 555 0187", y: 0.45),
                     ocrLine("T 512-555-0142", y: 0.4), ocrLine("(512) 555-0142", y: 0.35)]
        let card = CardParser().parse(items: lines.map { OCRItem(text: $0.text, box: $0.box) })
        XCTAssertEqual(card.phones.count, 2)
        XCTAssertEqual(card.phones.map(\.label), [.mobile, .main])
    }

    func testDedupeKeepsLabeledVariant() {
        let phones = parser.dedupePhones([
            LabeledNumber(label: .unknown, number: "408-555-1234"),
            LabeledNumber(label: .main,    number: "TEL: 408-555-1234"),
        ])
        XCTAssertEqual(phones.count, 1)
        XCTAssertEqual(phones.first?.number, "TEL: 408-555-1234")
    }
}
