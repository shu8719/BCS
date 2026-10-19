import XCTest
@testable import BCS

final class LocalTimeTests: XCTestCase {
    private let at = ISO8601DateFormatter().date(from: "2026-10-19T14:17:00Z")!

    func testHourMinuteInZone() {
        XCTAssertEqual(LocalTime.hourMinute(in: "America/New_York", at: at), "10:17")
        XCTAssertEqual(LocalTime.hourMinute(in: "America/Los_Angeles", at: at), "07:17")
        XCTAssertEqual(LocalTime.hourMinute(in: "Asia/Tokyo", at: at), "23:17")
    }

    func testLocalTimeIsNilWithoutIdentifier() {
        XCTAssertNil(LocalTime.hourMinute(in: "", at: at))
        XCTAssertNil(LocalTime.hourMinute(in: "Not/AZone", at: at))
        XCTAssertNil(LocalTime.hoursFromJapan(in: "", at: at))
    }

    func testHoursFromJapan() {
        XCTAssertEqual(LocalTime.hoursFromJapan(in: "America/New_York", at: at), -13)
        XCTAssertEqual(LocalTime.hoursFromJapan(in: "America/Los_Angeles", at: at), -16)
        XCTAssertEqual(LocalTime.hoursFromJapan(in: "Asia/Tokyo", at: at), 0)
    }
}
