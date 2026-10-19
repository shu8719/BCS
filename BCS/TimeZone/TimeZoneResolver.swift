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

/// Maps a US business card to PST / MST / CST / EST using the ZIP (preferred) or the phone area code.
/// Databases are injectable so tests can load the CSVs from the repository instead of Bundle.main.
struct TimeZoneResolver {
    var zipDB: TimeZoneLookupTable
    var areaDB: TimeZoneLookupTable

    init(zipDB: TimeZoneLookupTable = .bundledZip, areaDB: TimeZoneLookupTable = .bundledAreaCode) {
        self.zipDB = zipDB
        self.areaDB = areaDB
    }

    // MARK: - Static convenience using the bundled databases

    // Safe to call from any thread; DispatchQueue.sync inside stays off the main thread.
    static func resolveUpdates(for cards: [BusinessCard]) -> [TimeZoneUpdate] {
        TimeZoneResolver().resolveUpdates(for: cards)
    }

    static func resolve(for card: BusinessCard) -> (meta: TimeZoneMeta, sourceKey: String)? {
        TimeZoneResolver().resolve(for: card)
    }

    // MARK: - Resolution

    /// Batch-resolves all cards that need a timezone update.
    func resolveUpdates(for cards: [BusinessCard]) -> [TimeZoneUpdate] {
        cards.compactMap { card in
            guard let (meta, sourceKey) = resolve(for: card) else {
                // No longer resolvable (e.g. address edited to a non-US one):
                // clear any stale timezone instead of leaving the old badge in place.
                let hasStale = !card.timeZoneId.isEmpty || card.timeZone != nil || card.timeZoneSource != nil
                return hasStale ? TimeZoneUpdate(cardID: card.id, code: "", identifier: "", sourceKey: "") : nil
            }
            guard card.timeZoneId.isEmpty || card.timeZoneSource != TimeZoneSource(legacySourceKey: sourceKey) else { return nil }
            return TimeZoneUpdate(cardID: card.id, code: meta.code ?? "", identifier: meta.identifier, sourceKey: sourceKey)
        }
    }

    func resolve(for card: BusinessCard) -> (meta: TimeZoneMeta, sourceKey: String)? {
        let addr = card.address.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !addr.isEmpty, Self.looksLikeUSAddress(addr, phones: card.phones) else { return nil }

        if let zip = Self.extractUSZip(from: addr), let tzId = zipDB.timeZoneIdentifier(for: zip) {
            return (TimeZoneMeta(identifier: tzId, code: Self.code(forTimeZoneIdentifier: tzId)), zip)
        }
        if let area = Self.extractUSAreaCode(from: card.phones), let tzId = areaDB.timeZoneIdentifier(for: area) {
            return (TimeZoneMeta(identifier: tzId, code: Self.code(forTimeZoneIdentifier: tzId)), "AC:\(area)")
        }
        return nil
    }

    // MARK: - US detection

    private static let usCountryMatcher = KeywordMatcher([
        "united states of america", "united states", "u.s.a.", "u.s.", "usa", "us"
    ])
    // A state code counts only when it directly precedes the ZIP ("San Jose, CA 95110"),
    // so English words such as "IN", "OR" or "HI" elsewhere in the address do not match.
    // Group 1 captures the 5-digit ZIP.
    private static let stateZipRegex: NSRegularExpression? = {
        let states = usStateCodes.sorted().joined(separator: "|")
        return try? NSRegularExpression(pattern: #"\b(?:"# + states + #")\.?,?\s+(\d{5})(?:-\d{4})?\b"#)
    }()
    private static let zipRegex = try? NSRegularExpression(pattern: #"\b(\d{5})(?:-\d{4})?\b"#)

    static func looksLikeUSAddress(_ address: String, phones: [LabeledNumber]) -> Bool {
        if usCountryMatcher.matches(address) { return true }
        if stateZipMatch(in: address.uppercased()) != nil { return true }
        if phones.contains(where: { $0.number.contains("+1") }) { return true }
        return false
    }

    private static func stateZipMatch(in upper: String) -> NSTextCheckingResult? {
        guard let re = stateZipRegex else { return nil }
        return re.firstMatch(in: upper, range: NSRange(location: 0, length: (upper as NSString).length))
    }

    /// Prefers the ZIP that follows a state code ("CA 92121"). Otherwise takes the last 5-digit run,
    /// because a leading 5-digit number is usually the street number ("10300 Harbor View Dr").
    static func extractUSZip(from s: String) -> String? {
        let upper = s.uppercased()
        let ns = upper as NSString
        if let m = stateZipMatch(in: upper), m.numberOfRanges > 1 {
            return ns.substring(with: m.range(at: 1))
        }
        guard let re = zipRegex,
              let m = re.matches(in: upper, range: NSRange(location: 0, length: ns.length)).last,
              m.numberOfRanges > 1 else { return nil }
        return ns.substring(with: m.range(at: 1))
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

    // MARK: - Code mapping

    /// Maps an IANA identifier to PST / MST / CST / EST by its *standard* UTC offset.
    /// Deliberately avoids `TimeZone.abbreviation`, which depends on the device locale
    /// (a Japanese device returns "GMT-4" instead of "EDT") and silently produced empty codes.
    static func code(forTimeZoneIdentifier identifier: String) -> String? {
        guard let tz = TimeZone(identifier: identifier) else { return nil }
        let now = Date()
        let standardOffset = tz.secondsFromGMT(for: now) - Int(tz.daylightSavingTimeOffset(for: now))
        switch standardOffset {
        case -8 * 3600: return "PST"
        case -7 * 3600: return "MST"
        case -6 * 3600: return "CST"
        case -5 * 3600: return "EST"
        default: return nil
        }
    }
}
