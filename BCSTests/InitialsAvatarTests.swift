import XCTest
@testable import BCS

final class InitialsAvatarTests: XCTestCase {
    func testInitialsFromTwoWords() {
        XCTAssertEqual(InitialsAvatar.initials(of: "DAVID MORGAN"), "RD")
        XCTAssertEqual(InitialsAvatar.initials(of: "Mark Ellis"), "LN")
        XCTAssertEqual(InitialsAvatar.initials(of: "  Linda   Chen "), "XW")
    }

    func testInitialsFromSingleWord() {
        XCTAssertEqual(InitialsAvatar.initials(of: "Northwind"), "AS")
        XCTAssertEqual(InitialsAvatar.initials(of: "山田太郎"), "山田")
    }

    func testInitialsForEmpty() {
        XCTAssertEqual(InitialsAvatar.initials(of: ""), "?")
        XCTAssertEqual(InitialsAvatar.initials(of: "   "), "?")
    }

    func testToneIsStableAndRotatesPrimaryTertiarySecondary() {
        // Unicode scalar sum mod 3 → [primary, tertiary, secondary]
        XCTAssertEqual(AvatarTone.tone(for: "Mark Ellis"), .tertiary)     // sum % 3 == 1
        XCTAssertEqual(AvatarTone.tone(for: "DAVID MORGAN"), .secondary)   // sum % 3 == 2
        XCTAssertEqual(AvatarTone.tone(for: "Linda Chen"), .secondary)     // sum % 3 == 2
        XCTAssertEqual(AvatarTone.tone(for: ""), .primary)                  // sum % 3 == 0
        XCTAssertEqual(AvatarTone.tone(for: "Mark Ellis"), AvatarTone.tone(for: "Mark Ellis"))
    }
}
