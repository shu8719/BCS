import Foundation

/// Applies the "要確認" rules the parser can decide on its own:
/// - US phone numbers are reformatted to "+1 NXX-NXX-XXXX"; the original is kept in rawValue but a
///   pure reformat (separators, +1) is NOT flagged. A number whose digit count is wrong is flagged
///   `.malformed` and left as read. International numbers and numbers with an extension are left alone.
/// - empty name / company → `.missing`
/// `.inferred` (company guessed from the e-mail domain) is set by CardParser; the ZIP / area-code
/// conflict by the time zone resolver.
enum ReviewFlagger {
    static func apply(to card: inout BusinessCard) {
        for i in card.phones.indices {
            let original = card.phones[i].number
            if let normalized = PhoneNormalizer.normalizeUS(original) {
                card.phones[i].field = ContactField(normalized, rawValue: normalized == original ? nil : original)
            } else if PhoneNormalizer.hasExtension(original) || PhoneNormalizer.isInternational(original) {
                continue
            } else if card.phones[i].field.reviewReason == nil {
                card.phones[i].field.reviewReason = .malformed
            }
        }
        if card.name.value.isEmpty { card.name.reviewReason = .missing }
        if card.company.value.isEmpty { card.company.reviewReason = .missing }
        if card.address.value.isEmpty { card.address.reviewReason = .missing }
    }
}
