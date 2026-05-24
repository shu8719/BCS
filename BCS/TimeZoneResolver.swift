import Foundation

struct TimeZoneMeta {
    let identifier: String
    let code: String?
}

struct TimeZoneUpdate {
    let cardID: UUID
    let code: String
    let identifier: String
    let sourceKey: String
}

struct TimeZoneResolver {
    // Batch-resolves all cards that need a timezone update.
    // Safe to call from any thread; DispatchQueue.sync inside stays off the main thread.
    static func resolveUpdates(for cards: [BusinessCard]) -> [TimeZoneUpdate] {
        cards.compactMap { card in
            guard let (meta, sourceKey) = resolve(for: card) else { return nil }
            guard card.timeZoneId.isEmpty || card.timeZoneSourceAddress != sourceKey else { return nil }
            return TimeZoneUpdate(cardID: card.id, code: meta.code ?? "", identifier: meta.identifier, sourceKey: sourceKey)
        }
    }

    static func resolve(for card: BusinessCard) -> (meta: TimeZoneMeta, sourceKey: String)? {
        let addr = card.address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !addr.isEmpty, looksLikeUSAddress(addr, phones: card.phones) else { return nil }

        if let zip = extractUSZip(from: addr), let meta = resolveFromZip(zip) {
            return (meta, zip)
        }
        if let area = extractUSAreaCode(from: card.phones), let meta = resolveFromAreaCode(area) {
            return (meta, "AC:\(area)")
        }
        return nil
    }

    private static func looksLikeUSAddress(_ address: String, phones: [LabeledNumber]) -> Bool {
        let upper = address.uppercased()
        if upper.contains("UNITED STATES") || upper.contains("U.S.") || upper.contains("USA") || upper.contains(" US ") {
            return true
        }
        if let zip = extractUSZip(from: upper), !zip.isEmpty, containsUSStateCode(upper) {
            return true
        }
        if phones.contains(where: { $0.number.contains("+1") }) {
            return true
        }
        return false
    }

    private static func containsUSStateCode(_ upper: String) -> Bool {
        let tokens = upper.split { !$0.isLetter }
        return tokens.contains { usStateCodes.contains(String($0)) }
    }

    private static func extractUSZip(from s: String) -> String? {
        let pattern = #"\b\d{5}(?:-\d{4})?\b"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return String((ns.substring(with: m.range)).prefix(5))
    }

    private static func extractUSAreaCode(from phones: [LabeledNumber]) -> String? {
        for phone in phones {
            let raw = phone.number
            let digits = raw.filter(\.isNumber)
            if raw.contains("+1"), digits.count >= 11 {
                let start = digits.index(after: digits.startIndex)
                let end = digits.index(start, offsetBy: 3, limitedBy: digits.endIndex) ?? digits.endIndex
                return String(digits[start..<end])
            }
            if digits.count == 10 { return String(digits.prefix(3)) }
            if digits.count > 10, digits.hasPrefix("1") {
                let start = digits.index(after: digits.startIndex)
                let end = digits.index(start, offsetBy: 3, limitedBy: digits.endIndex) ?? digits.endIndex
                return String(digits[start..<end])
            }
        }
        return nil
    }

    private static func resolveFromZip(_ zip: String) -> TimeZoneMeta? {
        guard let tzId = ZipTimeZoneDB.shared.timeZoneIdentifier(for: zip) else { return nil }
        return TimeZoneMeta(identifier: tzId, code: normalizeTimeZoneIdentifier(tzId))
    }

    private static func resolveFromAreaCode(_ areaCode: String) -> TimeZoneMeta? {
        guard let tzId = AreaCodeTimeZoneDB.shared.timeZoneIdentifier(for: areaCode) else { return nil }
        return TimeZoneMeta(identifier: tzId, code: normalizeTimeZoneIdentifier(tzId))
    }

    private static func normalizeTimeZoneIdentifier(_ tzId: String) -> String? {
        if let tz = TimeZone(identifier: tzId) {
            let abbr = tz.abbreviation(for: Date()) ?? ""
            switch abbr {
            case "PST", "PDT": return "PST"
            case "MST", "MDT": return "MST"
            case "CST", "CDT": return "CST"
            case "EST", "EDT": return "EST"
            default: break
            }
        }
        let lower = tzId.lowercased()
        if lower.contains("pacific")  { return "PST" }
        if lower.contains("mountain") { return "MST" }
        if lower.contains("central")  { return "CST" }
        if lower.contains("eastern")  { return "EST" }
        return nil
    }
}
