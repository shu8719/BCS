import XCTest
@testable import BCS

@MainActor
final class CardStoreTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CardStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func card(_ name: String) -> BusinessCard {
        var c = BusinessCard()
        c.name = ContactField(name)
        c.company = "ACME"
        return c
    }

    func testAppendPersistsAndReloads() {
        let store = CardStore(directory: directory)
        store.append(card("A"))
        store.append(card("B"))

        let reloaded = CardStore(directory: directory)
        XCTAssertEqual(reloaded.cards.map(\.name.value), ["A", "B"])
    }

    func testUpdateReplacesById() {
        let store = CardStore(directory: directory)
        var a = card("A")
        store.append(a)
        a.company = "Renamed"
        store.update(a)
        XCTAssertEqual(store.card(id: a.id)?.company.value, "Renamed")
        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(CardStore(directory: directory).cards.first?.company.value, "Renamed")
    }

    func testDeleteManyThenUndoRestoresOrder() {
        let store = CardStore(directory: directory)
        let a = card("A"), b = card("B"), c = card("C")
        [a, b, c].forEach(store.append)

        store.delete(ids: [a.id, c.id])
        XCTAssertEqual(store.cards.map(\.name.value), ["B"])
        XCTAssertEqual(store.undoState?.operation, .deleteMany(2))

        store.restoreUndo()
        XCTAssertEqual(store.cards.map(\.name.value), ["A", "B", "C"])
        XCTAssertNil(store.undoState)
    }

    func testDeleteByIdThenUndo() {
        let store = CardStore(directory: directory)
        let a = card("A")
        store.append(a)
        store.delete(id: a.id)
        XCTAssertTrue(store.cards.isEmpty)
        XCTAssertEqual(store.undoState?.operation, .deleteSingle)
        store.restoreUndo()
        XCTAssertEqual(store.cards.map(\.id), [a.id])
    }

    func testMarkAllReviewedClearsEveryField() {
        let store = CardStore(directory: directory)
        var c = BusinessCard()
        c.name = ContactField("", reviewReason: .missing)
        c.company = "ACME"
        c.phones = [LabeledNumber(label: .direct, field: ContactField("+1 407-555-0173", rawValue: "D: 407-555.0173", reviewReason: .normalized))]
        store.append(c)
        store.markAllReviewed(id: c.id)
        XCTAssertEqual(store.card(id: c.id)?.reviewCount, 0)
        XCTAssertEqual(CardStore(directory: directory).cards.first?.reviewCount, 0)
    }

    func testLoadsV1StateFileAndKeepsCardsAfterSave() throws {
        let v1 = """
        {"version":1,"selectedIndex":0,"cards":[
          {"id":"8C8D5B3A-6D1E-4F3E-9D6B-1F2E3D4C5B6A","name":"John Smith","company":"ACME Inc.",
           "phones":[{"id":"1C8D5B3A-6D1E-4F3E-9D6B-1F2E3D4C5B6A","label":"main","number":"TEL: 408-555-1234"}],
           "email":"john@acme.com","address":"123 Main St, San Jose, CA 95110",
           "timeZoneCode":"PST","timeZoneId":"America/Los_Angeles","timeZoneSourceAddress":"95110"}]}
        """
        try Data(v1.utf8).write(to: directory.appendingPathComponent("business_cards.json"))

        let store = CardStore(directory: directory)
        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.cards.first?.name.value, "John Smith")
        XCTAssertEqual(store.cards.first?.timeZone, .pst)
        XCTAssertEqual(store.cards.first?.scannedAt, .distantPast)

        store.append(card("New"))
        let reloaded = CardStore(directory: directory)
        XCTAssertEqual(reloaded.cards.map(\.name.value), ["John Smith", "New"])
        XCTAssertEqual(reloaded.cards.first?.phones.first?.number, "TEL: 408-555-1234")
    }

    func testUnreadableFileIsSetAsideNotOverwritten() throws {
        let json = directory.appendingPathComponent("business_cards.json")
        try Data("{not json".utf8).write(to: json)

        let store = CardStore(directory: directory)
        XCTAssertTrue(store.cards.isEmpty)
        store.append(card("A"))

        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertTrue(names.contains { $0.hasPrefix("business_cards.unreadable-") }, "\(names)")
        XCTAssertEqual(CardStore(directory: directory).cards.count, 1)
    }
}
