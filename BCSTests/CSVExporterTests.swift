import XCTest
@testable import BCS

final class CSVExporterTests: XCTestCase {
    private func card(name: String, company: String = "ACME", address: String = "", phones: [String] = [], email: String = "", tz: String = "") -> BusinessCard {
        var c = BusinessCard()
        c.name = ContactField(name); c.company = ContactField(company); c.address = ContactField(address)
        c.phones = phones.map { LabeledNumber(label: .unknown, number: $0) }
        c.email = ContactField(email); c.timeZone = USTimeZone(rawValue: tz)
        return c
    }

    func testStartsWithBOMAndUsesCRLF() {
        let csv = CSVExporter.makeCSV(cards: [card(name: "John Smith")], lang: .english)
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}"))
        XCTAssertTrue(csv.contains("\r\n"))
        XCTAssertFalse(csv.contains("\n\n"))
    }

    func testHeaderFollowsLanguage() {
        let en = CSVExporter.makeCSV(cards: [], lang: .english)
        let ja = CSVExporter.makeCSV(cards: [], lang: .japanese)
        XCTAssertEqual(en.dropFirst(), "Name,Company,Address,Phone,Email,Time Zone,Needs review,Raw value")
        XCTAssertEqual(ja.dropFirst(), "名前,会社,住所,電話,メール,タイムゾーン,要確認,読み取り元")
    }

    func testEscapesCommasQuotesAndNewlines() {
        let c = card(name: "Smith, John", company: "Say \"Hi\" Inc.", address: "Line 1\nLine 2")
        let row = CSVExporter.makeCSV(cards: [c], lang: .english).components(separatedBy: "\r\n")[1]
        XCTAssertEqual(row, "\"Smith, John\",\"Say \"\"Hi\"\" Inc.\",\"Line 1\nLine 2\",,,,,")
    }

    func testJoinsPhonesWithSlash() {
        let c = card(name: "A", phones: ["TEL: 408-555-1234", "M: 650-555-0000"], tz: "PST")
        let row = CSVExporter.makeCSV(cards: [c], lang: .english).components(separatedBy: "\r\n")[1]
        XCTAssertEqual(row, "A,ACME,,TEL: 408-555-1234 / M: 650-555-0000,,PST,,")
    }

    func testAppendsReviewColumns() {
        var c = card(name: "A")
        c.phones = [LabeledNumber(label: .direct, field: ContactField("+1 407-555-0173", rawValue: "D: 407-555.0173", reviewReason: .normalized))]
        let row = CSVExporter.makeCSV(cards: [c], lang: .english).components(separatedBy: "\r\n")[1]
        XCTAssertEqual(row, "A,ACME,,+1 407-555-0173,,,TRUE,D: 407-555.0173")
    }

    func testReviewColumnsEmptyWhenClean() {
        let row = CSVExporter.makeCSV(cards: [card(name: "A")], lang: .english).components(separatedBy: "\r\n")[1]
        XCTAssertTrue(row.hasSuffix(",,"), row)
    }

    func testWritesTemporaryFile() throws {
        let url = try CSVExporter.writeTemporaryFile(cards: [card(name: "A")], lang: .english)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(url.pathExtension, "csv")
        let contents = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(contents.contains("A,ACME"))
    }
}
