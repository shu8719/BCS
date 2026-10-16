import XCTest
@testable import BCS

/// Runs the parser over every fixture in BCSTests/Fixtures and reports per-field accuracy.
/// Add fixtures by exporting them from the app's DEBUG "開発用" section in Settings.
final class FixtureAccuracyTests: XCTestCase {
    /// Minimum accuracy per field. These start at 0 so the corpus can be collected first;
    /// raise them once ~20 fixtures are in place so regressions fail the build.
    private let minimumAccuracy: [FixtureEvaluator.Field: Double] = [
        .name: 0, .company: 0, .phones: 0, .email: 0, .address: 0, .timeZone: 0,
    ]

    func testCorpusAccuracy() throws {
        let directory = FixtureLoader.defaultDirectory
        let fixtures = try FixtureLoader.loadAll(from: directory)
        try XCTSkipIf(fixtures.isEmpty, "No fixtures found in \(directory.path)")

        let report = FixtureEvaluator(resolver: repoTimeZoneResolver()).evaluate(fixtures)
        print(report.summary)

        for (field, minimum) in minimumAccuracy {
            let count = report.count(for: field)
            guard count.checked > 0 else { continue }
            XCTAssertGreaterThanOrEqual(
                count.accuracy, minimum,
                "\(field.rawValue): \(count.correct)/\(count.checked) is below the minimum \(minimum)\n\(report.summary)"
            )
        }
    }
}
