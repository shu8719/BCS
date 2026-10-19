import Foundation

enum CardSort: CaseIterable {
    case scannedAtDesc, scannedAtAsc, nameAsc, companyAsc
}

enum CardGroup: Equatable {
    case thisWeek, earlier
}

struct CardListQuery: Equatable {
    var search = ""
    var needsReviewOnly = false
    var company: String? = nil
    var zone: USTimeZone? = nil
    var sort: CardSort = .scannedAtDesc
}

/// Pure list logic for the card list screen: search, filters, sort and week grouping.
enum CardListFilter {
    static func apply(_ query: CardListQuery, to cards: [BusinessCard]) -> [BusinessCard] {
        let needle = query.search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = cards.filter { card in
            if !needle.isEmpty {
                let haystack = [card.name.value, card.company.value, card.email.value].map { $0.lowercased() }
                guard haystack.contains(where: { $0.contains(needle) }) else { return false }
            }
            if query.needsReviewOnly, !card.needsReview { return false }
            if let company = query.company, card.company.value != company { return false }
            if let zone = query.zone, card.timeZone != zone { return false }
            return true
        }
        return filtered.sorted { a, b in
            switch query.sort {
            case .scannedAtDesc:
                if a.scannedAt != b.scannedAt { return a.scannedAt > b.scannedAt }
                return a.name.value.localizedCaseInsensitiveCompare(b.name.value) == .orderedAscending
            case .scannedAtAsc:
                if a.scannedAt != b.scannedAt { return a.scannedAt < b.scannedAt }
                return a.name.value.localizedCaseInsensitiveCompare(b.name.value) == .orderedAscending
            case .nameAsc:
                return a.name.value.localizedCaseInsensitiveCompare(b.name.value) == .orderedAscending
            case .companyAsc:
                let c = a.company.value.localizedCaseInsensitiveCompare(b.company.value)
                if c != .orderedSame { return c == .orderedAscending }
                return a.name.value.localizedCaseInsensitiveCompare(b.name.value) == .orderedAscending
            }
        }
    }
    
    /// Splits into "this week" (scanned on or after Monday of the current week) and "earlier".
    /// Empty groups are omitted. Cards without a scan date (distantPast) land in "earlier".
    static func group(_ cards: [BusinessCard], now: Date, calendar: Calendar) -> [(group: CardGroup, cards: [BusinessCard])] {
        var cal = calendar
        cal.firstWeekday = 2
        let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let thisWeek = cards.filter { $0.scannedAt >= weekStart }
        let earlier = cards.filter { $0.scannedAt < weekStart }
        var result: [(group: CardGroup, cards: [BusinessCard])] = []
        if !thisWeek.isEmpty { result.append((.thisWeek, thisWeek)) }
        if !earlier.isEmpty { result.append((.earlier, earlier)) }
        return result
    }
    
    /// Distinct, non-empty company names, alphabetical.
    static func companies(in cards: [BusinessCard]) -> [String] {
        Array(Set(cards.map(\.company.value).filter { !$0.isEmpty }))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
