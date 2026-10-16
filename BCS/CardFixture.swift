import Foundation
import CoreGraphics

/// A recorded OCR result plus the expected parse result.
/// Exported from the app's DEBUG settings and consumed by `FixtureAccuracyTests`.
/// Only text and boxes are stored, never the card image.
struct CardFixture: Codable, Equatable {
    enum Source: String, Codable, CaseIterable, Identifiable {
        case paper      // a physical card photographed with the document camera
        case screen     // a card shown on a tablet/monitor, photographed with the camera
        case image      // an image file run through OCR directly (DEBUG photo import)
        case synthetic  // hand-written, not real OCR output
        
        var id: String { rawValue }
    }
    
    struct Item: Codable, Equatable {
        var text: String
        var x: Double
        var y: Double
        var w: Double
        var h: Double
        
        init(text: String, x: Double, y: Double, w: Double, h: Double) {
            self.text = text; self.x = x; self.y = y; self.w = w; self.h = h
        }
        
        init(_ item: OCRItem) {
            self.init(text: item.text,
                      x: Double(item.box.origin.x), y: Double(item.box.origin.y),
                      w: Double(item.box.width), h: Double(item.box.height))
        }
        
        var ocrItem: OCRItem {
            OCRItem(text: text, box: CGRect(x: x, y: y, width: w, height: h))
        }
    }
    
    /// Each field is optional: `nil` means "do not check this field".
    struct Expected: Codable, Equatable {
        var name: String?
        var company: String?
        var phones: [String]?
        var email: String?
        var address: String?
        var timeZoneCode: String?
        
        init() {}
        
        init(card: BusinessCard, timeZoneCode: String?) {
            name = card.name
            company = card.company
            phones = card.phones.map(\.number)
            email = card.email
            address = card.address
            self.timeZoneCode = timeZoneCode ?? ""
        }
    }
    
    var name: String
    var source: Source
    var createdAt: String
    var notes: String
    var items: [Item]
    var expected: Expected
    
    init(name: String, source: Source, createdAt: String = ISO8601DateFormatter().string(from: Date()),
         notes: String = "", items: [Item], expected: Expected) {
        self.name = name
        self.source = source
        self.createdAt = createdAt
        self.notes = notes
        self.items = items
        self.expected = expected
    }
    
    /// Builds a fixture whose expected values are prefilled with the parser's current output,
    /// so only the wrong fields have to be corrected by hand.
    init(name: String, source: Source, items: [OCRItem], card: BusinessCard, timeZoneCode: String?) {
        self.init(name: name, source: source,
                  items: items.map { Item($0) },
                  expected: Expected(card: card, timeZoneCode: timeZoneCode))
    }
    
    var ocrItems: [OCRItem] { items.map(\.ocrItem) }
    
    static func encode(_ fixture: CardFixture) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(fixture)
    }
    
    static func decode(_ data: Data) throws -> CardFixture {
        try JSONDecoder().decode(CardFixture.self, from: data)
    }
}
