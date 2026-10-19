import Foundation

/// Formats North American numbers as "+1 NXX-NXX-XXXX". Anything else is left alone.
enum PhoneNormalizer {
    private static let extensionRegex = try? NSRegularExpression(
        pattern: #"ext|#|(?<![a-z])x\s*\d"#, options: [.caseInsensitive]
    )
    
    /// Returns the normalized form, or nil when the number is not a plain 10-digit US number
    /// (11 digits with a leading 1 are accepted). Numbers with an extension are never touched.
    static func hasExtension(_ raw: String) -> Bool {
        guard let re = extensionRegex else { return false }
        return re.firstMatch(in: raw, range: NSRange(location: 0, length: (raw as NSString).length)) != nil
    }
    
    /// "+81 …", "+44 …": a country code other than +1.
    static func isInternational(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("+") && !t.hasPrefix("+1")
    }
    
    /// Digits to dial (with a leading "+" when present), cut before any extension marker:
    /// "408-555-1234 x 102" → "4085551234", "+1 407-555-0173" → "+14075550173".
    static func dialable(_ raw: String) -> String {
        var head = raw
        if let re = extensionRegex,
           let m = re.firstMatch(in: raw, range: NSRange(location: 0, length: (raw as NSString).length)) {
            head = (raw as NSString).substring(to: m.range.location)
        }
        let digits = head.filter(\.isNumber)
        return (head.contains("+") && !digits.isEmpty ? "+" : "") + digits
    }
    
    static func normalizeUS(_ raw: String) -> String? {
        if let re = extensionRegex,
           re.firstMatch(in: raw, range: NSRange(location: 0, length: (raw as NSString).length)) != nil {
            return nil
        }
        var digits = raw.filter(\.isNumber)
        if digits.count == 11, digits.hasPrefix("1") {
            digits.removeFirst()
        }
        guard digits.count == 10, let first = digits.first, ("2"..."9").contains(first) else { return nil }
        
        let area = digits.prefix(3)
        let exchange = digits.dropFirst(3).prefix(3)
        let line = digits.suffix(4)
        return "+1 \(area)-\(exchange)-\(line)"
    }
}
