import Foundation

/// Text for the detail screen, kept out of the view so it can be unit-tested.
enum CardDetailText {
    private static let separator = " ・ "
    
    /// "現地時刻 23:17 ・ 日本との時差 −13時間"; nil when the card has no zone.
    static func timeZoneLine(card: BusinessCard, now: Date, lang: AppSettings.Language) -> String? {
        guard let zone = card.timeZone else { return nil }
        let identifier = card.timeZoneId.isEmpty ? zone.representativeIdentifier : card.timeZoneId
        guard let time = LocalTime.hourMinute(in: identifier, at: now),
              let diff = LocalTime.hoursFromJapan(in: identifier, at: now) else { return nil }
        return L10n.t(.localTimeLine, lang: lang, time, signed(diff))
    }
    
    /// "2026/10/19 にスキャン ・ 郵便番号 32826 からタイムゾーンを自動判定"
    static func metaLine(card: BusinessCard, lang: AppSettings.Language) -> String {
        var parts: [String] = []
        if card.scannedAt != .distantPast {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy/MM/dd"
            parts.append(L10n.t(.scannedOn, lang: lang, formatter.string(from: card.scannedAt)))
        }
        if let source = card.timeZoneSource {
            switch source {
            case .zip(let zip):       parts.append(L10n.t(.tzFromZip, lang: lang, zip))
            case .areaCode(let area): parts.append(L10n.t(.tzFromAreaCode, lang: lang, area))
            case .manual:             parts.append(L10n.t(.tzManual, lang: lang))
            }
        }
        return parts.joined(separator: separator)
    }
    
    /// One-line explanation under the banner title, chosen from the first flagged field.
    static func reviewBannerSubtitle(card: BusinessCard, lang: AppSettings.Language) -> String? {
        guard let reason = card.allFields.compactMap(\.reviewReason).first else { return nil }
        switch reason {
        case .normalized:       return L10n.t(.reviewSubtitleNormalized, lang: lang)
        case .malformed:        return L10n.t(.reviewSubtitleMalformed, lang: lang)
        case .missing:          return L10n.t(.reviewSubtitleMissing, lang: lang)
        case .inferred:         return L10n.t(.reviewSubtitleInferred, lang: lang)
        case .timeZoneConflict: return L10n.t(.reviewNoteTZConflict, lang: lang)
        }
    }
    
    /// Note shown under a flagged field row.
    static func reviewNote(field: ContactField, lang: AppSettings.Language) -> String? {
        guard let reason = field.reviewReason else { return nil }
        switch reason {
        case .normalized:       return L10n.t(.reviewNoteNormalized, lang: lang, field.rawValue ?? "")
        case .malformed:        return L10n.t(.reviewNoteMalformed, lang: lang)
        case .missing:          return L10n.t(.reviewNoteMissing, lang: lang)
        case .inferred:         return L10n.t(.reviewNoteInferred, lang: lang)
        case .timeZoneConflict: return L10n.t(.reviewNoteTZConflict, lang: lang)
        }
    }
    
    static func phoneLabel(_ label: PhoneLabel, lang: AppSettings.Language) -> String {
        switch label {
        case .direct:  return L10n.t(.phoneDirect, lang: lang)
        case .main:    return L10n.t(.phoneMain, lang: lang)
        case .mobile:  return L10n.t(.phoneMobile, lang: lang)
        case .unknown: return L10n.t(.phoneGeneric, lang: lang)
        }
    }
    
    /// "−13" (U+2212 minus), "+2", "0"
    private static func signed(_ hours: Int) -> String {
        if hours < 0 { return "\u{2212}\(-hours)" }
        if hours > 0 { return "+\(hours)" }
        return "0"
    }
}
