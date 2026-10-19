import Foundation

/// Applies the "要確認" rules from UI_REDESIGN_HANDOFF.md §4 that the parser can decide on its own:
/// 1. a phone number was reformatted (original kept in rawValue)
/// 2. name or company is empty
/// Rule 3 (ZIP vs area-code conflict) is applied by the time zone resolver.
enum ReviewFlagger {
    static func apply(to card: inout BusinessCard) {
        for i in card.phones.indices {
            let original = card.phones[i].number
            if let normalized = PhoneNormalizer.normalizeUS(original), normalized != original {
                card.phones[i].field = ContactField(normalized, rawValue: original, reviewReason: .normalized)
            }
        }
        if card.name.value.isEmpty { card.name.reviewReason = .missing }
        if card.company.value.isEmpty { card.company.reviewReason = .missing }
    }
}
