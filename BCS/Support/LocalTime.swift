import Foundation

/// Local-time helpers for a card's IANA time zone.
enum LocalTime {
    private static let japan = TimeZone(identifier: "Asia/Tokyo")!
    
    /// "23:17" in the given zone, or nil when the identifier is empty or unknown.
    static func hourMinute(in identifier: String, at date: Date) -> String? {
        guard !identifier.isEmpty, let tz = TimeZone(identifier: identifier) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = tz
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    /// Whole hours relative to Japan at the given instant (New York in October → -13).
    static func hoursFromJapan(in identifier: String, at date: Date) -> Int? {
        guard !identifier.isEmpty, let tz = TimeZone(identifier: identifier) else { return nil }
        return (tz.secondsFromGMT(for: date) - japan.secondsFromGMT(for: date)) / 3600
    }
}
