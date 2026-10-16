import XCTest
@testable import BCS

final class FixtureEvaluatorTests: XCTestCase {
    private func fixture(_ name: String, _ configure: (inout CardFixture.Expected) -> Void) -> CardFixture {
        var expected = CardFixture.Expected()
        configure(&expected)
        return CardFixture(name: name, source: .synthetic, items: sampleUSCardItems().map { CardFixture.Item($0) }, expected: expected)
    }

    func testCountsMatchingFieldAsCorrectAndSkipsUnsetFields() {
        let report = FixtureEvaluator(resolver: nil).evaluate([fixture("a") { $0.name = "John Smith" }])

        XCTAssertEqual(report.count(for: .name).checked, 1)
        XCTAssertEqual(report.count(for: .name).correct, 1)
        XCTAssertEqual(report.count(for: .company).checked, 0)
        XCTAssertTrue(report.failures.isEmpty)
    }

    func testRecordsMismatchWithExpectedAndActual() {
        let report = FixtureEvaluator(resolver: nil).evaluate([fixture("a") { $0.name = "Jane Doe" }])

        XCTAssertEqual(report.count(for: .name).correct, 0)
        XCTAssertEqual(report.failures.count, 1)
        XCTAssertEqual(report.failures.first?.fixture, "a")
        XCTAssertEqual(report.failures.first?.field, .name)
        XCTAssertEqual(report.failures.first?.expected, "Jane Doe")
        XCTAssertEqual(report.failures.first?.actual, "John Smith")
    }

    func testPhonesCompareByDigitsIgnoringLabelsAndFormatting() {
        let report = FixtureEvaluator(resolver: nil).evaluate([fixture("a") { $0.phones = ["(408) 555-1234"] }])
        XCTAssertEqual(report.count(for: .phones).correct, 1)
    }

    func testAddressComparesIgnoringCaseAndSpacing() {
        let report = FixtureEvaluator(resolver: nil).evaluate([fixture("a") { $0.address = "123 webster avenue, san jose, ca 95110" }])
        XCTAssertEqual(report.count(for: .address).correct, 1)
    }

    func testSummaryListsEveryFieldWithCounts() {
        let report = FixtureEvaluator(resolver: nil).evaluate([fixture("a") { $0.name = "John Smith"; $0.email = "john.smith@acme.com" }])
        XCTAssertTrue(report.summary.contains("name"), report.summary)
        XCTAssertTrue(report.summary.contains("1/1"), report.summary)
    }
}
