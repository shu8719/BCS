#if DEBUG
import Foundation
import Observation

/// Keeps the most recent OCR result so the DEBUG settings section can export it as a test fixture.
@MainActor
@Observable
final class FixtureRecorder {
    static let shared = FixtureRecorder()
    
    private(set) var lastItems: [OCRItem] = []
    private(set) var lastCard: BusinessCard?
    /// Where the last scan came from: .paper for the camera, .image for a photo.
    /// A card photographed off a screen should be changed to "screen" in the exported JSON by hand.
    private(set) var lastSource: CardFixture.Source = .paper
    
    private init() {}
    
    var hasRecord: Bool { lastCard != nil }
    
    func record(items: [OCRItem], card: BusinessCard, source: CardFixture.Source) {
        lastItems = items
        lastCard = card
        lastSource = source
    }
    
    func makeFixture() -> CardFixture? {
        guard let card = lastCard else { return nil }
        let timeZoneCode = TimeZoneResolver.resolve(for: card)?.zone?.rawValue
        return CardFixture(name: Self.fixtureName(for: card, source: lastSource),
                           source: lastSource, items: lastItems, card: card, timeZoneCode: timeZoneCode)
    }
    
    /// e.g. "paper_acme_electronics_inc_20261016_173000"
    static func fixtureName(for card: BusinessCard, source: CardFixture.Source, date: Date = Date()) -> String {
        let base = [card.company.value, card.name.value].first { !$0.isEmpty } ?? "card"
        var slug = base.lowercased()
            .map { ($0.isASCII && ($0.isLetter || $0.isNumber)) ? String($0) : "_" }
            .joined()
            .replacingOccurrences(of: #"_+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        if slug.isEmpty { slug = "card" }
        slug = String(slug.prefix(24))
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "\(source.rawValue)_\(slug)_\(formatter.string(from: date))"
    }
}
#endif
