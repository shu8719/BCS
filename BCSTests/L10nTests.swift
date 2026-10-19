import XCTest
@testable import BCS

final class L10nTests: XCTestCase {
    func testLanguageSegmentLabelsAreShort() {
        XCTAssertEqual(L10n.t(.langAuto, lang: .japanese), "自動")
        XCTAssertEqual(L10n.t(.langAuto, lang: .english), "Auto")
    }

    func testFormatArguments() {
        XCTAssertEqual(L10n.t(.selectedCount, lang: .japanese, 2), "2 件を選択中")
        XCTAssertEqual(L10n.t(.localTime, lang: .english, "23:17"), "Local 23:17")
    }
}
