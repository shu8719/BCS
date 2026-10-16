import Foundation
@testable import BCS

/// Runs `CardParser` over fixtures and tallies per-field correctness.
struct FixtureEvaluator {
    enum Field: String, CaseIterable {
        case name, company, phones, email, address, timeZone
    }
    
    struct Count {
        var checked = 0
        var correct = 0
        var accuracy: Double { checked == 0 ? 1 : Double(correct) / Double(checked) }
    }
    
    struct Failure: Equatable {
        let fixture: String
        let field: Field
        let expected: String
        let actual: String
    }
    
    struct Report {
        var fixtureCount = 0
        var counts: [Field: Count] = [:]
        var failures: [Failure] = []
        
        func count(for field: Field) -> Count { counts[field] ?? Count() }
        
        var summary: String {
            var lines = ["Fixture accuracy (\(fixtureCount) fixtures)"]
            for field in Field.allCases {
                let c = count(for: field)
                let pct = c.checked == 0 ? "   -  " : String(format: "%5.1f%%", c.accuracy * 100)
                lines.append(String(format: "  %-9@ %3d/%-3d %@", field.rawValue as NSString, c.correct, c.checked, pct))
            }
            if !failures.isEmpty {
                lines.append("Failures:")
                for f in failures {
                    lines.append("  [\(f.fixture)] \(f.field.rawValue): expected \"\(f.expected)\" / actual \"\(f.actual)\"")
                }
            }
            return lines.joined(separator: "\n")
        }
    }
    
    /// Resolver used for the timeZone field; `nil` skips that field.
    var resolver: TimeZoneResolver?
    
    func evaluate(_ fixtures: [CardFixture]) -> Report {
        let parser = CardParser()
        var report = Report(fixtureCount: fixtures.count)
        
        func check(_ field: Field, fixture: String, expected: String?, actual: String,
                   normalize: (String) -> String) {
            guard let expected else { return }
            var c = report.count(for: field)
            c.checked += 1
            if normalize(expected) == normalize(actual) {
                c.correct += 1
            } else {
                report.failures.append(Failure(fixture: fixture, field: field, expected: expected, actual: actual))
            }
            report.counts[field] = c
        }
        
        for fixture in fixtures {
            let card = parser.parse(items: fixture.ocrItems)
            let e = fixture.expected
            
            check(.name,    fixture: fixture.name, expected: e.name,    actual: card.name,    normalize: Self.text)
            check(.company, fixture: fixture.name, expected: e.company, actual: card.company, normalize: Self.text)
            check(.email,   fixture: fixture.name, expected: e.email,   actual: card.email,   normalize: Self.text)
            check(.address, fixture: fixture.name, expected: e.address, actual: card.address, normalize: Self.alphanumeric)
            check(.phones,  fixture: fixture.name,
                  expected: e.phones.map { $0.joined(separator: " / ") },
                  actual: card.phones.map(\.number).joined(separator: " / "),
                  normalize: Self.phoneDigitSet)
            if let resolver {
                let actual = resolver.resolve(for: card)?.meta.code ?? ""
                check(.timeZone, fixture: fixture.name, expected: e.timeZoneCode, actual: actual,
                      normalize: { $0.trimmingCharacters(in: .whitespaces).uppercased() })
            }
        }
        
        return report
    }
    
    // MARK: - Normalizers
    
    nonisolated private static func text(_ s: String) -> String {
        s.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
    }
    
    nonisolated private static func alphanumeric(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }
    
    /// "TEL: (408) 555-1234 / 650-555-0000" -> "4085551234|6505550000" (sorted set of digit strings)
    nonisolated private static func phoneDigitSet(_ s: String) -> String {
        Set(s.split(separator: "/").map { $0.filter(\.isNumber) }.filter { !$0.isEmpty })
            .sorted()
            .joined(separator: "|")
    }
}

enum FixtureLoader {
    /// BCSTests/Fixtures next to this source file; works in Xcode and in a SwiftPM checkout.
    static var defaultDirectory: URL {
        URL(fileURLWithPath: #filePath).resolvingSymlinksInPath()
            .deletingLastPathComponent().appendingPathComponent("Fixtures")
    }
    
    struct LoadError: Error, CustomStringConvertible {
        let file: String
        let underlying: Error
        var description: String { "Could not decode fixture \(file): \(underlying)" }
    }
    
    static func loadAll(from directory: URL) throws -> [CardFixture] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return [] }
        return try names
            .filter { $0.hasSuffix(".json") }
            .sorted()
            .map { name in
                let url = directory.appendingPathComponent(name)
                do {
                    return try CardFixture.decode(try Data(contentsOf: url))
                } catch {
                    throw LoadError(file: name, underlying: error)
                }
            }
    }
}
