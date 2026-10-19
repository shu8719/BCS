import XCTest
@testable import BCS

final class CardDetailTextTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-10-19T14:17:00Z")!
    private let scanned = ISO8601DateFormatter().date(from: "2026-10-19T12:00:00Z")!

    private func card(zone: USTimeZone? = .est, id: String = "America/New_York",
                      source: TimeZoneSource? = .zip("32826")) -> BusinessCard {
        var c = BusinessCard()
        c.name = "DAVID MORGAN"
        c.timeZone = zone
        c.timeZoneId = id
        c.timeZoneSource = source
        c.scannedAt = scanned
        return c
    }

    func testTimeZoneLineForEST() {
        XCTAssertEqual(CardDetailText.timeZoneLine(card: card(), now: now, lang: .japanese),
                       "現地時刻 10:17 ・ 日本との時差 −13時間")
    }

    func testTimeZoneLineIsNilWithoutZone() {
        XCTAssertNil(CardDetailText.timeZoneLine(card: card(zone: nil, id: "", source: nil), now: now, lang: .japanese))
    }

    func testMetaLineFromZip() {
        XCTAssertEqual(CardDetailText.metaLine(card: card(), lang: .japanese),
                       "2026/10/19 にスキャン ・ 郵便番号 32826 からタイムゾーンを自動判定")
    }

    func testMetaLineFromAreaCodeAndManual() {
        XCTAssertEqual(CardDetailText.metaLine(card: card(source: .areaCode("407")), lang: .japanese),
                       "2026/10/19 にスキャン ・ 市外局番 407 からタイムゾーンを自動判定")
        XCTAssertEqual(CardDetailText.metaLine(card: card(source: .manual), lang: .japanese),
                       "2026/10/19 にスキャン ・ タイムゾーンは手動設定")
    }

    func testMetaLineWithoutTimeZone() {
        XCTAssertEqual(CardDetailText.metaLine(card: card(zone: nil, id: "", source: nil), lang: .japanese),
                       "2026/10/19 にスキャン")
    }

    func testMetaLineForLegacyCardWithoutScanDate() {
        var c = card()
        c.scannedAt = .distantPast
        XCTAssertEqual(CardDetailText.metaLine(card: c, lang: .japanese), "郵便番号 32826 からタイムゾーンを自動判定")
    }

    func testReviewNoteForNormalizedPhone() {
        let f = ContactField("+1 407-555-0173", rawValue: "D: 407-555.0173", reviewReason: .normalized)
        XCTAssertEqual(CardDetailText.reviewNote(field: f, lang: .japanese), "読み取り元: D: 407-555.0173 → 補正済み")
        XCTAssertEqual(CardDetailText.reviewNote(field: ContactField("", reviewReason: .missing), lang: .japanese), "読み取れませんでした")
        XCTAssertNil(CardDetailText.reviewNote(field: "clean", lang: .japanese))
    }

    func testNotesForMalformedAndInferred() {
        XCTAssertEqual(CardDetailText.reviewNote(field: ContactField("408-555-123", reviewReason: .malformed), lang: .japanese),
                       "電話番号の桁数が合いません")
        XCTAssertEqual(CardDetailText.reviewNote(field: ContactField("Ridgelinerobotics", reviewReason: .inferred), lang: .japanese),
                       "メールアドレスから推測しました")
        var c = card()
        c.company = ContactField("Ridgelinerobotics", reviewReason: .inferred)
        XCTAssertEqual(CardDetailText.reviewBannerSubtitle(card: c, lang: .japanese), "メールアドレスから推測した項目があります")
    }

    func testBannerSubtitleUsesFirstReason() {
        var c = card()
        c.phones = [LabeledNumber(label: .direct, field: ContactField("+1 407-555-0173", rawValue: "D: 407-555.0173", reviewReason: .normalized))]
        c.address = ContactField("x", reviewReason: .timeZoneConflict)
        XCTAssertEqual(CardDetailText.reviewBannerSubtitle(card: c, lang: .japanese), "読み取り時に書式を補正しました")
        c.phones = []
        XCTAssertEqual(CardDetailText.reviewBannerSubtitle(card: c, lang: .japanese), "郵便番号と市外局番の判定が異なります")
        c.address = "x"
        XCTAssertNil(CardDetailText.reviewBannerSubtitle(card: c, lang: .japanese))
    }

    func testPhoneLabels() {
        XCTAssertEqual(CardDetailText.phoneLabel(.direct, lang: .japanese), "直通")
        XCTAssertEqual(CardDetailText.phoneLabel(.main, lang: .japanese), "代表")
        XCTAssertEqual(CardDetailText.phoneLabel(.mobile, lang: .english), "Mobile")
        XCTAssertEqual(CardDetailText.phoneLabel(.unknown, lang: .english), "Phone")
    }
}
