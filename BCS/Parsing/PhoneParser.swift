import Foundation

final class PhoneParser {
    // Compiled once; NSRegularExpression / NSDataDetector are thread-safe.
    private static let labelRegex = try? NSRegularExpression(
        // Single-letter labels (T/M/D/P/F) may be followed by a colon or directly by the number
        // ("D 407-555.0173"); the boundary keeps "of:" / "ip:" from being read as F: / P:.
        pattern: #"(?i)(?:^|\b)(tel\.?|phone|ph\.?|mobile\.?|cell|office|direct|fax|facsimile)(?=\b|[:：])|(?<![\p{L}\p{N}])[TMDPCOF](?=\s*[:：]|\s+\+?\(?\d)"#
    )
    // Separators are horizontal whitespace only, so a number never spans two OCR lines.
    private static let numberRegexes: [NSRegularExpression] = [
        #"\+?\d{1,3}[ \t\-.]?\(?\d{2,4}\)?[ \t\-.]?\d{2,4}[ \t\-.]?\d{3,4}(?:[ \t]*(?:ext\.?|x|#)[ \t]*\d{1,6})?"#,
        #"0\d{1,4}[\-\t ]?\d{1,4}[\-\t ]?\d{3,4}(?:[ \t]*(?:ext\.?|x|#)[ \t]*\d{1,6})?"#
    ].compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    private static let phoneDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
    // "fax" / "facsimile" as whole words, or an "F:" label; "of:" and "Ref:" must not match.
    private static let faxRegex = try? NSRegularExpression(
        pattern: #"(?<![\p{L}\p{N}])(?:(?:fax|facsimile)(?![\p{L}\p{N}])|f[ \t]*:)"#,
        options: [.caseInsensitive]
    )

    struct DetectedPhone {
        let label: PhoneLabel
        let labelText: String   // normalized for display, e.g. "TEL", "D:"
        let labelRaw: String    // as it appeared in the text, e.g. "Phone", "D"
        let number: String
    }
    
    private struct LabelMatch {
        let label: PhoneLabel
        let labelText: String
        let raw: String
        let range: NSRange
        let isFax: Bool
    }
    
    func extractPhones(from lines: [OCRLine]) -> [LabeledNumber] {
        var phones: [LabeledNumber] = []
        
        for line in lines {
            let detected = extractPhonesFromText(line.text, allowMultiline: false)
            for item in detected {
                let formatted = formatLabeledNumber(labelText: item.labelText, number: item.number)
                phones.append(LabeledNumber(label: item.label, number: formatted))
            }
        }
        
        return dedupePhones(phones)
    }
    
    func extractPhonesFromWholeText(lines: [OCRLine]) -> [LabeledNumber] {
        let whole = lines.map(\.text).joined(separator: "\n")
        let detected = extractPhonesFromText(whole, allowMultiline: true)
        
        return detected.map {
            LabeledNumber(label: $0.label, number: formatLabeledNumber(labelText: $0.labelText, number: $0.number))
        }
    }
    
    func extractPhonesFromAddressText(_ address: String) -> (cleanAddress: String, phones: [LabeledNumber]) {
        guard !address.isEmpty else { return ("", []) }
        
        let detected = extractPhonesFromText(address, allowMultiline: true)
        let phones = dedupePhones(
            detected.map {
                LabeledNumber(label: $0.label, number: formatLabeledNumber(labelText: $0.labelText, number: $0.number))
            }
        )
        
        var clean = address
        for item in detected {
            let num = NSRegularExpression.escapedPattern(for: item.number)
            if !item.labelRaw.isEmpty {
                let label = NSRegularExpression.escapedPattern(for: item.labelRaw)
                let pattern = "(?<![\\p{L}\\p{N}])\(label)\\s*[:：]?\\s*\(num)"
                clean = clean.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
            }
            clean = clean.replacingOccurrences(of: num, with: "", options: [.regularExpression, .caseInsensitive])
        }
        
        let leftovers = detectPhoneCandidates(clean)
        for raw in leftovers {
            let digits = phoneDigits(raw)
            if looksLikePostalDigits(digits) { continue }
            if digits.count < 8 { continue }
            let pattern = NSRegularExpression.escapedPattern(for: raw)
            clean = clean.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        
        // Drop segments left with nothing meaningful after the numbers were removed
        // (orphaned labels such as "D" or bullets such as "•").
        let segments = clean
            .split(whereSeparator: { $0 == "/" })
            .map { normalizeSpace(String($0)) }
            .filter { seg in seg.filter { $0.isLetter || $0.isNumber }.count >= 2 }
        clean = segments.joined(separator: " / ")
        
        return (clean, phones)
    }
    
    /// Collapses the same number read several times ("+1 512 555 0187", "C 512-555-0187", "(512) 555-0187")
    /// into one entry, keeping the one that carries a label.
    func dedupePhones(_ phones: [LabeledNumber]) -> [LabeledNumber] {
        var indexByDigits: [String: Int] = [:]
        var out: [LabeledNumber] = []
        
        func hasLabel(_ s: String) -> Bool {
            s.contains { $0.isLetter }
        }
        
        for phone in phones {
            let digits = canonicalDigits(phone.number)
            guard !digits.isEmpty else { continue }
            
            if let idx = indexByDigits[digits] {
                let existing = out[idx]
                let newLabeled = phone.label != .unknown || hasLabel(phone.number)
                let oldLabeled = existing.label != .unknown || hasLabel(existing.number)
                if newLabeled && !oldLabeled {
                    out[idx] = phone
                } else if newLabeled == oldLabeled && phone.number.count > existing.number.count {
                    out[idx] = phone
                }
            } else {
                indexByDigits[digits] = out.count
                out.append(phone)
            }
        }
        
        return out
    }
    
    /// Digits with a leading US country code removed, so "+1 512…" and "512…" compare equal.
    private func canonicalDigits(_ s: String) -> String {
        let digits = phoneDigits(s)
        return (digits.count == 11 && digits.hasPrefix("1")) ? String(digits.dropFirst()) : digits
    }
    
    private func extractPhonesFromText(_ text: String, allowMultiline: Bool) -> [DetectedPhone] {
        guard !text.isEmpty else { return [] }
        
        let normalized = normalizePhoneContext(text)
        let labels = findLabelMatches(in: normalized)
        let numbers = extractNumberMatches(from: normalized)
        guard !numbers.isEmpty else { return [] }
        
        let sortedLabels = labels.sorted { $0.range.location < $1.range.location }
        let sortedNumbers = numbers.sorted { $0.range.location < $1.range.location }
        let maxDistance = allowMultiline ? 80 : 30
        
        var out: [DetectedPhone] = []
        // A label applies only to the first number after it. Otherwise, in
        // "Fax: 111\n222", the fax label would also swallow 222.
        var previousNumberEnd = -1
        
        for num in sortedNumbers {
            let digits = phoneDigits(num.number)
            if digits.count < 8 { continue }
            if looksLikePostalDigits(digits) { continue }
            if !isLikelyValidPhoneNumber(num.number) { continue }
            
            let label = sortedLabels.last(where: {
                $0.range.location < num.range.location && $0.range.location >= previousNumberEnd
            })
            previousNumberEnd = num.range.location + num.range.length
            
            if let label {
                let distance = num.range.location - (label.range.location + label.range.length)
                if distance <= maxDistance {
                    if label.isFax { continue }
                    out.append(DetectedPhone(label: label.label, labelText: label.labelText, labelRaw: label.raw, number: num.number))
                    continue
                }
            }
            
            // Unlabeled number: treat it as a fax number only when the fax keyword is on
            // the same line, not when it appears anywhere else on the card.
            if containsFaxKeyword(lineContaining(num.range, in: normalized)) { continue }
            out.append(DetectedPhone(label: .unknown, labelText: "", labelRaw: "", number: num.number))
        }
        
        return out
    }
    
    private func lineContaining(_ range: NSRange, in text: String) -> String {
        let ns = text as NSString
        let lineRange = ns.lineRange(for: NSRange(location: range.location, length: 0))
        return ns.substring(with: lineRange)
    }
    
    private func findLabelMatches(in text: String) -> [LabelMatch] {
        guard let re = Self.labelRegex else { return [] }
        
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        var matches: [LabelMatch] = []
        
        for m in re.matches(in: text, range: range) {
            let raw = ns.substring(with: m.range)
            let key = raw.lowercased()
            
            func add(_ label: PhoneLabel, _ text: String, isFax: Bool = false) {
                matches.append(LabelMatch(label: label, labelText: text, raw: raw, range: m.range, isFax: isFax))
            }
            
            switch key {
            case "tel", "tel.", "phone", "ph", "ph.", "office":
                add(.main, "TEL")
            case "mobile", "mobile.", "cell":
                add(.mobile, "Mobile")
            case "direct":
                add(.direct, "Direct")
            case "t", "p", "o":
                add(.main, "T:")
            case "m", "c":
                add(.mobile, "M:")
            case "d":
                add(.direct, "D:")
            case "fax", "facsimile", "f":
                add(.unknown, "FAX", isFax: true)
            default:
                continue
            }
        }
        
        return matches
    }
    
    private func extractNumberMatches(from text: String) -> [(range: NSRange, number: String)] {
        let ns = text as NSString
        var out: [(NSRange, String)] = []
        
        for re in Self.numberRegexes {
            let ms = re.matches(in: text, range: NSRange(location: 0, length: ns.length))
            for m in ms {
                var raw = trimRawPhoneMatch(ns.substring(with: m.range))
                raw = trimTrailingStreetNumber(raw, fullText: text, range: m.range)
                let cleaned = cleanPhoneNumber(raw)
                if phoneDigits(cleaned).count >= 8, isLikelyValidPhoneNumber(cleaned) {
                    out.append((m.range, cleaned))
                }
            }
        }
        
        if let detector = Self.phoneDetector {
            detector.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) { m, _, _ in
                guard let m else { return }
                guard m.resultType == .phoneNumber else { return }
                var raw = trimRawPhoneMatch(ns.substring(with: m.range))
                raw = trimTrailingStreetNumber(raw, fullText: text, range: m.range)
                let cleaned = cleanPhoneNumber(raw)
                if phoneDigits(cleaned).count >= 8, isLikelyValidPhoneNumber(cleaned) {
                    out.append((m.range, cleaned))
                }
            }
        }
        
        var seen = Set<String>()
        var deduped: [(NSRange, String)] = []
        for item in out.sorted(by: { $0.0.location < $1.0.location }) {
            let key = canonicalDigits(item.1)
            if seen.contains(key) { continue }
            seen.insert(key)
            deduped.append(item)
        }
        
        return deduped
    }
    
    private func cleanPhoneNumber(_ s: String) -> String {
        let cleaned = s.replacingOccurrences(of: #"[^0-9+\-\s\.\(\)#xXtTeErR]"#, with: "", options: .regularExpression)
        return normalizeSpace(cleaned)
    }
    
    private func trimRawPhoneMatch(_ raw: String) -> String {
        let pieces = raw.components(separatedBy: CharacterSet.newlines)
        guard pieces.count >= 2 else { return raw }
        
        let first = pieces.first ?? ""
        let rest = pieces.dropFirst().joined(separator: " ")
        if rest.rangeOfCharacter(from: .letters) != nil {
            return first
        }
        return raw
    }
    
    private func trimTrailingStreetNumber(_ raw: String, fullText: String, range: NSRange) -> String {
        let ns = fullText as NSString
        let end = range.location + range.length
        if end < ns.length {
            let tailLen = min(24, ns.length - end)
            let tail = ns.substring(with: NSRange(location: end, length: tailLen))
            if tail.rangeOfCharacter(from: .letters) == nil {
                return raw
            }
        }
        
        let lower = raw.lowercased()
        if lower.contains("ext") || lower.contains("x") || lower.contains("#") {
            return raw
        }
        
        let parts = raw.split(separator: " ")
        guard parts.count >= 2 else { return raw }
        let last = String(parts.last ?? "")
        if last.range(of: #"^\d{3,4}$"#, options: .regularExpression) == nil {
            return raw
        }
        
        let prev = parts.dropLast().joined(separator: " ")
        if phoneDigits(prev).count >= 8 {
            return prev
        }
        return raw
    }
    
    private func formatLabeledNumber(labelText: String, number: String) -> String {
        guard !labelText.isEmpty else { return number }
        if labelText.hasSuffix(":") {
            return "\(labelText) \(number)"
        }
        return "\(labelText): \(number)"
    }
    
    private func normalizePhoneContext(_ text: String) -> String {
        let t = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        return t
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "／", with: "/")
    }
    
    private func containsFaxKeyword(_ text: String) -> Bool {
        guard let re = Self.faxRegex else { return false }
        return re.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }
    
    private func detectPhoneCandidates(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        guard let detector = Self.phoneDetector else { return [] }
        
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        var out: [String] = []
        
        detector.enumerateMatches(in: text, options: [], range: range) { m, _, _ in
            guard let m else { return }
            guard m.resultType == .phoneNumber else { return }
            let raw = ns.substring(with: m.range)
            let cleaned = cleanPhoneNumber(raw)
            if phoneDigits(cleaned).count >= 8, isLikelyValidPhoneNumber(cleaned) {
                out.append(cleaned)
            }
        }
        
        return Array(Set(out))
    }
    
    private func isLikelyValidPhoneNumber(_ raw: String) -> Bool {
        let digits = phoneDigits(raw)
        if digits.count < 8 || digits.count > 15 { return false }
        
        if raw.range(of: #"\b\d{5}-\d{4}\s+\d{2,4}\b"#, options: .regularExpression) != nil {
            return false
        }
        
        let unique = Set(digits)
        if unique.count <= 2, unique.isSubset(of: Set(["0", "1"])) {
            return false
        }
        
        let hasPhonePunctuation = raw.contains("-") || raw.contains(".") || raw.contains("(") || raw.contains(")")
        || raw.contains(" ") || raw.lowercased().contains("ext") || raw.contains("+")
        if digits.count >= 11 && !hasPhonePunctuation {
            return false
        }
        
        return true
    }
    
    private func phoneDigits(_ s: String) -> String {
        s.filter(\.isNumber)
    }
    
    private func looksLikePostalDigits(_ d: String) -> Bool {
        d.count == 5 || d.count == 9
    }
    
}

