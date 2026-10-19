import XCTest
@testable import BCS

final class CardListFilterTests: XCTestCase {
    private func card(_ name: String, company: String = "", email: String = "", address: String = "",
                      zone: USTimeZone? = nil, review: Bool = false, scannedAt: Date = Date()) -> BusinessCard {
        var c = BusinessCard()
        c.name = ContactField(name, reviewReason: review ? .missing : nil)
        c.company = ContactField(company)
        c.email = ContactField(email)
        c.address = ContactField(address)
        c.timeZone = zone
        c.scannedAt = scannedAt
        return c
    }

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    func testSearchIsCaseInsensitiveAndTrimmed() {
        let a = card("David Morgan", company: "Northwind", address: "Orlando")
        let b = card("Linda Chen", company: "Amazon", email: "lindachen@amazon.com")
        var q = CardListQuery()
        q.search = "  north "
        XCTAssertEqual(CardListFilter.apply(q, to: [a, b]).map(\.id), [a.id])
        q.search = "LINDACHEN"
        XCTAssertEqual(CardListFilter.apply(q, to: [a, b]).map(\.id), [b.id])
        q.search = "orlando"   // address is not searched
        XCTAssertTrue(CardListFilter.apply(q, to: [a, b]).isEmpty)
    }

    func testNeedsReviewOnlyFilter() {
        let a = card("A", review: true), b = card("B")
        var q = CardListQuery(); q.needsReviewOnly = true
        XCTAssertEqual(CardListFilter.apply(q, to: [a, b]).map(\.id), [a.id])
    }

    func testCompanyAndZoneFilters() {
        let t = date("2026-10-01T00:00:00Z")   // same scan time, so the default sort falls back to name
        let a = card("A", company: "Northwind", zone: .est, scannedAt: t)
        let b = card("B", company: "Amazon", zone: .pst, scannedAt: t)
        let c = card("C", company: "Northwind", zone: .pst, scannedAt: t)
        var q = CardListQuery(); q.company = "Northwind"
        XCTAssertEqual(CardListFilter.apply(q, to: [a, b, c]).map(\.name.value), ["A", "C"])
        q.zone = .pst
        XCTAssertEqual(CardListFilter.apply(q, to: [a, b, c]).map(\.name.value), ["C"])
        XCTAssertEqual(CardListFilter.companies(in: [a, b, c, card("D")]), ["Amazon", "Northwind"])
    }

    func testSortByNameIsCaseInsensitive() {
        let cards = [card("bob"), card("Alice"), card("carol")]
        var q = CardListQuery(); q.sort = .nameAsc
        XCTAssertEqual(CardListFilter.apply(q, to: cards).map(\.name.value), ["Alice", "bob", "carol"])
        q.sort = .scannedAtDesc
        let older = card("Old", scannedAt: date("2026-01-01T00:00:00Z"))
        let newer = card("New", scannedAt: date("2026-10-01T00:00:00Z"))
        XCTAssertEqual(CardListFilter.apply(q, to: [older, newer]).map(\.name.value), ["New", "Old"])
        q.sort = .scannedAtAsc
        XCTAssertEqual(CardListFilter.apply(q, to: [newer, older]).map(\.name.value), ["Old", "New"])
    }

    func testGroupsByMondayStartOfWeek() {
        let now = date("2026-10-21T12:00:00Z")                 // Wednesday
        let monday = card("Mon", scannedAt: date("2026-10-19T00:30:00Z"))
        let sunday = card("Sun", scannedAt: date("2026-10-18T23:00:00Z"))
        let groups = CardListFilter.group([monday, sunday], now: now, calendar: utc)
        XCTAssertEqual(groups.map(\.group), [.thisWeek, .earlier])
        XCTAssertEqual(groups[0].cards.map(\.name.value), ["Mon"])
        XCTAssertEqual(groups[1].cards.map(\.name.value), ["Sun"])
    }

    func testCardsWithoutScanDateGoToEarlier() {
        let legacy = card("Legacy", scannedAt: .distantPast)
        let groups = CardListFilter.group([legacy], now: date("2026-10-21T12:00:00Z"), calendar: utc)
        XCTAssertEqual(groups.map(\.group), [.earlier])
    }

    func testEmptyGroupsAreOmitted() {
        let recent = card("R", scannedAt: date("2026-10-20T12:00:00Z"))
        let groups = CardListFilter.group([recent], now: date("2026-10-21T12:00:00Z"), calendar: utc)
        XCTAssertEqual(groups.map(\.group), [.thisWeek])
        XCTAssertTrue(CardListFilter.group([], now: Date(), calendar: utc).isEmpty)
    }
}
