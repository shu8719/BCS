import Foundation

final class PhoneParser {
    struct DetectedPhone {
        let label: PhoneLabel
        let labelText: String
        let number: String
    }
    
    private struct LabelMatch {
        let label: PhoneLabel
        let labelText: String
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
            if !item.labelText.isEmpty {
                let label = NSRegularExpression.escapedPattern(for: item.labelText)
                let pattern = "\(label)\\s*[:：]?\\s*\(num)"
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
        
        clean = clean
            .replacingOccurrences(of: #"(\s*/\s*){2,}"#, with: " / ", options: .regularExpression)
            .replacingOccurrences(of: #"\s*/\s*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*/\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (clean, phones)
    }
    
    func dedupePhones(_ phones: [LabeledNumber]) -> [LabeledNumber] {
        var indexByDigits: [String: Int] = [:]
        var out: [LabeledNumber] = []
        
        func hasLabel(_ s: String) -> Bool {
            s.contains { $0.isLetter }
        }
        
        for phone in phones {
            let digits = phoneDigits(phone.number)
            guard !digits.isEmpty else { continue }
            
            if let idx = indexByDigits[digits] {
                let existing = out[idx].number
                let newHas = hasLabel(phone.number)
                let oldHas = hasLabel(existing)
                if newHas && !oldHas {
                    out[idx] = phone
                } else if newHas == oldHas && phone.number.count > existing.count {
                    out[idx] = phone
                }
            } else {
                indexByDigits[digits] = out.count
                out.append(phone)
            }
        }
        
        return out
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
        
        for num in sortedNumbers {
            let digits = phoneDigits(num.number)
            if digits.count < 8 { continue }
            if looksLikePostalDigits(digits) { continue }
            if !isLikelyValidPhoneNumber(num.number) { continue }
            
            if let label = sortedLabels.last(where: { $0.range.location < num.range.location }) {
                let distance = num.range.location - (label.range.location + label.range.length)
                if distance <= maxDistance {
                    if label.isFax { continue }
                    out.append(DetectedPhone(label: label.label, labelText: label.labelText, number: num.number))
                    continue
                }
            }
            
            if containsFaxKeyword(normalized.lowercased()) { continue }
            out.append(DetectedPhone(label: .unknown, labelText: "", number: num.number))
        }
        
        return out
    }
    
    private func findLabelMatches(in text: String) -> [LabelMatch] {
        let pattern = #"(?i)(?:^|\b)(tel\.?|phone|ph\.?|mobile\.?|direct|fax|facsimile)(?=\b|[:：])|[TMDP]:"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        var matches: [LabelMatch] = []
        
        for m in re.matches(in: text, range: range) {
            let raw = ns.substring(with: m.range)
            let key = raw.lowercased()
            
            switch key {
            case "tel", "tel.":
                matches.append(LabelMatch(label: .main, labelText: "TEL", range: m.range, isFax: false))
            case "phone", "ph", "ph.":
                matches.append(LabelMatch(label: .main, labelText: "TEL", range: m.range, isFax: false))
            case "mobile", "mobile.":
                matches.append(LabelMatch(label: .mobile, labelText: "Mobile", range: m.range, isFax: false))
            case "direct":
                matches.append(LabelMatch(label: .direct, labelText: "Direct", range: m.range, isFax: false))
            case "t:":
                matches.append(LabelMatch(label: .main, labelText: "T:", range: m.range, isFax: false))
            case "m:":
                matches.append(LabelMatch(label: .mobile, labelText: "M:", range: m.range, isFax: false))
            case "d:":
                matches.append(LabelMatch(label: .direct, labelText: "D:", range: m.range, isFax: false))
            case "p:":
                matches.append(LabelMatch(label: .main, labelText: "T:", range: m.range, isFax: false))
            case "fax", "facsimile":
                matches.append(LabelMatch(label: .unknown, labelText: "FAX", range: m.range, isFax: true))
            default:
                continue
            }
        }
        
        return matches
    }
    
    private func extractNumberMatches(from text: String) -> [(range: NSRange, number: String)] {
        let patterns = [
            #"\+?\d{1,3}[\s\-.]?\(?\d{2,4}\)?[\s\-.]?\d{2,4}[\s\-.]?\d{3,4}(?:\s*(?:ext\.?|x|#)\s*\d{1,6})?"#,
            #"0\d{1,4}[-\s]?\d{1,4}[-\s]?\d{3,4}(?:\s*(?:ext\.?|x|#)\s*\d{1,6})?"#
        ]
        let regexes = patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
        
        let ns = text as NSString
        var out: [(NSRange, String)] = []
        
        for re in regexes {
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
        
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue) {
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
            let key = phoneDigits(item.1)
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
    
    private func containsFaxKeyword(_ lower: String) -> Bool {
        let keys = ["fax", "facsimile", "fax:", "f:"]
        return keys.contains(where: { lower.contains($0) })
    }
    
    private func detectPhoneCandidates(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue) else {
            return []
        }
        
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

