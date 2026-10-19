import Foundation
import CoreGraphics

/// Finds the postal address block among OCR lines.
///
/// Pipeline (see `pickAddressBlockInfo`):
/// 1. classify lines that look like addresses ("strong" lines)
/// 2. grow a block around each strong line from adjacent, aligned continuation lines
/// 3. merge vertically adjacent blocks, score them and keep the best
/// 4. pull in a neighbour just below / above that alignment checks missed
/// 5. clean each line (labels, web tokens, phone notes) and join with " / "
final class AddressParser {
    // NSDataDetector creation is expensive and these are called for every OCR line
    // from several parsers, so build them once. NSDataDetector is thread-safe.
    private static let addressDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue)
    private static let contactLineMatcher = KeywordMatcher([
        "tel", "phone", "mobile", "cell", "fax", "facsimile", "e-mail", "email", "mail", "web", "website", "http", "www"
    ])
    private static let phoneWordMatcher = KeywordMatcher(["tel", "phone", "mobile", "cell", "office", "direct", "main"])
    private static let addressSuffixMatcher = KeywordMatcher([
        "street", "st", "road", "rd", "avenue", "ave", "drive", "dr", "suite", "floor", "building"
    ])
    private static let addressLabelKeywordMatcher = KeywordMatcher([
        "address", "office address", "location", "head office", "addr"
    ])
    // A phone number with at most a bullet and/or a short label in front: "• 407.555.0162", "D 407-555.0173".
    private static let barePhoneRegex = try? NSRegularExpression(
        pattern: #"^(?:[•·\-–—*|]+\s*)?(?:(?:tel|phone|ph|mobile|cell|direct|office|main|fax|t|m|d|p|c|f)\.?\s*[:：\-]?\s*)?\+?[\d\s().\-]*\d[\d\s().\-]*(?:\s*(?:ext\.?|x|#)\s*\d{1,6})?$"#,
        options: [.caseInsensitive]
    )
    
    // MARK: - Public API
    
    func pickAddressBlockInfo(from lines: [OCRLine]) -> (text: String, box: CGRect?) {
        guard !lines.isEmpty else { return ("", nil) }
        
        let ordered = lines.sorted { $0.box.midY > $1.box.midY }
        let strongIndices = ordered.indices.filter { looksLikeAddressLine(ordered[$0].text) }
        
        if strongIndices.isEmpty {
            return (detectAddressFallback(from: joinedText(ordered)), nil)
        }
        
        let layout = Layout(lines: ordered)
        let blocks = growBlocks(around: strongIndices, in: ordered, layout: layout)
        let merged = mergeAdjacentBlocks(blocks, layout: layout)
        let best = merged.max(by: { blockScore($0) < blockScore($1) }) ?? merged[0]
        
        var chosen = best.sorted { $0.box.midY > $1.box.midY }
        chosen = pullInNeighborBelow(chosen, from: ordered, layout: layout)
        chosen = pullInNeighborAbove(chosen, from: ordered, layout: layout)
        
        let text = cleanedText(of: chosen)
        if text.isEmpty {
            return (detectAddressFallback(from: joinedText(ordered)), nil)
        }
        return (text, unionBox(chosen))
    }
    
    /// Second pass: a block introduced by an "Address:" label, or the first few address-like lines.
    func recoverAddress(from lines: [OCRLine]) -> String {
        guard !lines.isEmpty else { return "" }
        let ordered = lines.sorted { $0.box.midY > $1.box.midY }
        
        for i in ordered.indices {
            let start = normalizeSpace(ordered[i].text)
            if !containsAddressLabelKeyword(start) { continue }
            let block = recoverLabelBlock(from: ordered, startIndex: i)
            let cleanedBlock = unique(block.map { cleanAddressLine($0) }).filter { !$0.isEmpty }
            if !cleanedBlock.isEmpty { return cleanedBlock.joined(separator: " / ") }
        }
        
        let addressLike = ordered
            .map { cleanAddressLine($0.text) }
            .filter { t in
                if t.isEmpty || isAddressLabelOnly(t) { return false }
                let lower = t.lowercased()
                if t.contains("@") || containsContactKeyword(lower) { return false }
                return looksLikeAddressLine(t) || looksLikeStateZipLine(t)
            }
        
        return unique(addressLike.prefix(3).map { $0 }).joined(separator: " / ")
    }
    
    // MARK: - Block assembly
    
    /// Vertical tolerance and horizontal alignment rules derived from the card's typical line height.
    private struct Layout {
        let yThreshold: CGFloat
        private let alignMidXThreshold: CGFloat = 0.18
        private let overlapThreshold: CGFloat = 0.25
        
        init(lines: [OCRLine]) {
            let medianHeight = AddressParser.median(lines.map(\.box.height))
            yThreshold = max(0.012, medianHeight * 1.8)
        }
        
        func overlapRatio(_ a: CGRect, _ b: CGRect) -> CGFloat {
            let left = max(a.minX, b.minX)
            let right = min(a.maxX, b.maxX)
            let overlap = max(0, right - left)
            let base = max(min(a.width, b.width), 0.001)
            return overlap / base
        }
        
        func isAligned(_ a: CGRect, _ b: CGRect) -> Bool {
            let midXDiff = abs(a.midX - b.midX)
            return overlapRatio(a, b) >= overlapThreshold || midXDiff <= alignMidXThreshold
        }
        
        func isJoinable(_ a: OCRLine, _ b: OCRLine) -> Bool {
            let dy = abs(a.box.midY - b.box.midY)
            return dy <= yThreshold && isAligned(a.box, b.box)
        }
    }
    
    /// For each strong line, walks up and down through adjacent, aligned continuation lines.
    private func growBlocks(around strongIndices: [Int], in ordered: [OCRLine], layout: Layout) -> [[OCRLine]] {
        var used = Set<Int>()
        var blocks: [[OCRLine]] = []
        
        for idx in strongIndices {
            if used.contains(idx) { continue }
            var block: [OCRLine] = [ordered[idx]]
            used.insert(idx)
            
            var i = idx - 1
            var anchor = ordered[idx]
            while i >= 0 {
                let line = ordered[i]
                if layout.isJoinable(line, anchor) && looksLikeAddressContinuation(line.text) {
                    block.insert(line, at: 0)
                    used.insert(i)
                    anchor = line
                } else if abs(line.box.midY - anchor.box.midY) > layout.yThreshold * 1.8 {
                    break
                }
                i -= 1
            }
            
            var j = idx + 1
            anchor = ordered[idx]
            while j < ordered.count {
                let line = ordered[j]
                if layout.isJoinable(line, anchor) && looksLikeAddressContinuation(line.text) {
                    block.append(line)
                    used.insert(j)
                    anchor = line
                } else if abs(line.box.midY - anchor.box.midY) > layout.yThreshold * 1.8 {
                    break
                }
                j += 1
            }
            
            blocks.append(block)
        }
        
        return blocks
    }
    
    /// Joins blocks that sit directly under each other and share a column.
    private func mergeAdjacentBlocks(_ blocks: [[OCRLine]], layout: Layout) -> [[OCRLine]] {
        let sortedBlocks = blocks.sorted { unionBox($0).midY > unionBox($1).midY }
        var merged: [[OCRLine]] = []
        for block in sortedBlocks {
            if let last = merged.last {
                let lastBox = unionBox(last)
                let box = unionBox(block)
                let verticalGap = abs(lastBox.minY - box.maxY)
                if verticalGap <= layout.yThreshold * 1.6 && layout.isAligned(lastBox, box) {
                    merged[merged.count - 1].append(contentsOf: block)
                    continue
                }
            }
            merged.append(block)
        }
        return merged
    }
    
    private func blockScore(_ block: [OCRLine]) -> Int {
        let t = block.map(\.text).joined(separator: " ").lowercased()
        var score = 0
        score += block.count * 12
        if t.range(of: #"\b[A-Z]{2}\s*\d{5}(?:-\d{4})?\b"#, options: .regularExpression) != nil { score += 24 }
        if t.contains("street") || t.contains("drive") || t.contains("suite") || t.contains("road") { score += 10 }
        if t.range(of: #"\b\d{4}\s+[a-záéíóöőúüű\.-]+"#, options: .regularExpression) != nil { score += 18 }
        if t.rangeOfCharacter(from: .decimalDigits) != nil { score += 6 }
        if isContactLine(t) { score -= 35 }
        return score
    }
    
    /// If the chosen block is missing an indented continuation line just below it,
    /// pull in the nearest address-like line even when alignment checks failed.
    private func pullInNeighborBelow(_ block: [OCRLine], from ordered: [OCRLine], layout: Layout) -> [OCRLine] {
        guard let bottom = block.last else { return block }
        let candidates = ordered
            .filter { $0.box.midY < bottom.box.midY }
            .map { line -> (OCRLine, CGFloat) in (line, abs(bottom.box.minY - line.box.maxY)) }
            .sorted { $0.1 < $1.1 }
        
        guard let pick = candidates.first(where: { line, gap in
            if gap > layout.yThreshold * 2.2 { return false }
            if Self.isSameLine(line, bottom) { return false }
            if block.contains(where: { Self.isSameLine($0, line) }) { return false }
            let t = normalizeSpace(line.text)
            if t.isEmpty || isAddressLabelOnly(t) { return false }
            return looksLikeAddressContinuation(t) || looksLikeStateZipLine(t)
        }) else { return block }
        
        return (block + [pick.0]).sorted { $0.box.midY > $1.box.midY }
    }
    
    /// Same for a street line sitting just above the chosen block.
    private func pullInNeighborAbove(_ block: [OCRLine], from ordered: [OCRLine], layout: Layout) -> [OCRLine] {
        guard let top = block.first else { return block }
        let candidates = ordered
            .filter { $0.box.midY > top.box.midY }
            .map { line -> (OCRLine, CGFloat) in (line, abs(line.box.minY - top.box.maxY)) }
            .sorted { $0.1 < $1.1 }
        
        guard let pick = candidates.first(where: { line, gap in
            if gap > layout.yThreshold * 3.0 { return false }
            if block.contains(where: { Self.isSameLine($0, line) }) { return false }
            let t = normalizeSpace(line.text)
            if t.isEmpty || isAddressLabelOnly(t) { return false }
            return looksLikeAddressLine(t) || looksLikeStateZipLine(t)
        }) else { return block }
        
        return (block + [pick.0]).sorted { $0.box.midY > $1.box.midY }
    }
    
    private func cleanedText(of block: [OCRLine]) -> String {
        let cleaned = block
            .map { cleanAddressLine($0.text) }
            .filter { !$0.isEmpty }
            .map { stripLeadingPersonNameFromAddressLine($0) }
            .filter { !$0.isEmpty && !isAddressLabelOnly($0) }
        return unique(cleaned).joined(separator: " / ")
    }
    
    private func unionBox(_ block: [OCRLine]) -> CGRect {
        block.map(\.box).reduce(block[0].box) { $0.union($1) }
    }
    
    private func joinedText(_ lines: [OCRLine]) -> String {
        lines.map(\.text).joined(separator: "\n")
    }
    
    private static func isSameLine(_ a: OCRLine, _ b: OCRLine) -> Bool {
        a.text == b.text && a.box == b.box
    }
    
    private static func median(_ values: [CGFloat]) -> CGFloat {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
    
    // MARK: - Label-based recovery
    
    private func recoverLabelBlock(from ordered: [OCRLine], startIndex: Int) -> [String] {
        var block: [String] = []
        var j = startIndex + 1
        
        while j < ordered.count && block.count < 5 {
            let t = normalizeSpace(ordered[j].text)
            let lower = t.lowercased()
            if t.isEmpty { j += 1; continue }
            if t.contains("@") || containsContactKeyword(lower) || isJobTitleLine(lower) { break }
            if looksLikeAddressLine(t) || looksLikeAddressContinuation(t) || looksLikeStateZipLine(t) {
                block.append(t)
            } else if block.isEmpty && t.count <= 60 {
                block.append(t)
            } else {
                break
            }
            j += 1
        }
        
        return unique(block).filter { !isAddressLabelOnly($0) }
    }
    
    /// Last resort: the longest address NSDataDetector finds in the whole text.
    private func detectAddressFallback(from text: String) -> String {
        guard !text.isEmpty else { return "" }
        guard let detector = Self.addressDetector else { return "" }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        var best = ""
        
        detector.enumerateMatches(in: text, options: [], range: range) { m, _, _ in
            guard let m else { return }
            if m.resultType == .address {
                let s = normalizeSpace(ns.substring(with: m.range))
                if s.count > best.count { best = s }
            }
        }
        return best
    }
    
    // MARK: - Line classification
    
    /// A line that can anchor an address block on its own.
    func looksLikeAddressLine(_ line: String) -> Bool {
        let t = normalizeSpace(line)
        let lower = t.lowercased()
        
        if t.isEmpty { return false }
        if isAddressLabelOnly(t) { return false }
        if isPhoneContactLine(t) { return false }
        if isBarePhoneLine(t) { return false }
        if isStandaloneContactLabel(t) { return false }
        if t.contains("@") || lower.contains("http") || lower.contains("www") { return false }
        if isContactLine(lower) { return false }
        
        if matchesAddressDetector(t) { return true }
        
        let hasDigits = t.rangeOfCharacter(from: .decimalDigits) != nil
        let hasLetters = t.range(of: #"\p{L}{2,}"#, options: .regularExpression) != nil
        let hasComma = t.contains(",")
        let hasAddressWord = t.range(of: #"\b(street|st\.?|road|rd\.?|avenue|ave\.?|drive|dr\.?|suite|ste\.?|floor|fl\.?|building|blvd\.?|boulevard|lane|ln\.?|way|plaza|parkway|pkwy\.?|po box)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
        let hasStateZip = t.range(of: #"\b[A-Z]{2}\s+\d{5}(?:-\d{4})?\b"#, options: .regularExpression) != nil
        
        if t.range(of: #"\b\d{4,6}(?:-\d{3,4})?\b"#, options: .regularExpression) != nil { return true }
        if t.range(of: #"^\d{1,5}\s+\p{L}{2,}"#, options: .regularExpression) != nil { return true }
        if hasAddressWord { return true }
        if hasStateZip { return true }
        if hasComma && hasDigits && hasLetters { return true }
        if hasDigits && hasLetters && t.split(separator: " ").count <= 8 { return true }
        
        return false
    }
    
    /// A line that may extend a block (looser than `looksLikeAddressLine`).
    private func looksLikeAddressContinuation(_ line: String) -> Bool {
        let t = normalizeSpace(line)
        let lower = t.lowercased()
        
        if t.isEmpty { return false }
        if isPhoneContactLine(t) { return false }
        if isBarePhoneLine(t) { return false }
        if isStandaloneContactLabel(t) { return false }
        if t.contains("@") || lower.contains("http") || lower.contains("www") { return false }
        if isContactLine(lower) { return false }
        if isJobTitleLine(lower) { return false }
        if isAddressLabelOnly(t) { return true }
        if looksLikeEnglishPersonName(t) && !looksLikeAddressWordLine(t) { return false }
        
        if looksLikeAddressLine(t) { return true }
        
        let hasDigits = t.rangeOfCharacter(from: .decimalDigits) != nil
        let hasLetters = t.range(of: #"\p{L}{2,}"#, options: .regularExpression) != nil
        let tokens = t.split(separator: " ").count
        let hasComma = t.contains(",")
        
        if (hasDigits || hasComma) && hasLetters { return true }
        if t.range(of: #"^\d{5}(?:-\d{4})?$"#, options: .regularExpression) != nil { return true }
        if (2...4).contains(tokens) && hasLetters { return true }
        
        return false
    }
    
    /// True for lines that are just a phone number (optionally with a bullet or a short label).
    /// Such lines otherwise pass the "contains a 4-6 digit run" address heuristic.
    func isBarePhoneLine(_ line: String) -> Bool {
        let t = normalizeSpace(line)
        guard let re = Self.barePhoneRegex,
              re.firstMatch(in: t, range: NSRange(location: 0, length: (t as NSString).length)) != nil else {
            return false
        }
        let digitCount = t.filter(\.isNumber).count
        return (7...15).contains(digitCount)
    }
    
    private func looksLikeAddressWordLine(_ line: String) -> Bool {
        let t = normalizeSpace(line)
        let lower = t.lowercased()
        
        if t.rangeOfCharacter(from: .decimalDigits) != nil || t.contains(",") { return true }
        
        if Self.addressSuffixMatcher.matches(lower) { return true }
        
        let tokens = t.split(separator: " ")
        if (1...3).contains(tokens.count) {
            let letters = t.filter { $0.isLetter }
            if !letters.isEmpty && letters.uppercased() == letters { return true }
        }
        
        return false
    }
    
    private func looksLikeStateZipLine(_ s: String) -> Bool {
        let t = normalizeSpace(s)
        if t.range(of: #"\b[A-Z]{2}\s+\d{5}(?:-\d{4})?\b"#, options: .regularExpression) != nil { return true }
        if t.range(of: #"\b\d{5}(?:-\d{4})?\b"#, options: .regularExpression) != nil && t.contains(",") { return true }
        return false
    }
    
    private func isAddressLabelOnly(_ line: String) -> Bool {
        let t = normalizeSpace(line)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":：- "))
            .lowercased()
        let labels = ["address", "office address", "location", "head office", "headquarters", "hq", "addr"]
        return labels.contains(t)
    }
    
    private func isPhoneContactLine(_ line: String) -> Bool {
        let t = normalizeSpace(line)
        let lower = t.lowercased()
        let hasPhoneWord = Self.phoneWordMatcher.matches(lower)
        let hasPhoneLikeDigits = t.range(of: #"(?:\+?\d[\d\-\s\(\)]{6,}\d)"#, options: .regularExpression) != nil
        return hasPhoneWord && hasPhoneLikeDigits
    }
    
    private func isStandaloneContactLabel(_ line: String) -> Bool {
        let t = normalizeSpace(line)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":：-./| "))
            .lowercased()
        let labels = ["office", "main", "direct", "mobile", "phone", "tel", "p", "c", "m", "t", "d", "f"]
        return labels.contains(t)
    }
    
    private func isContactLine(_ lower: String) -> Bool {
        Self.contactLineMatcher.matches(lower)
    }
    
    private func containsAddressLabelKeyword(_ s: String) -> Bool {
        Self.addressLabelKeywordMatcher.matches(normalizeSpace(s))
    }
    
    private func matchesAddressDetector(_ text: String) -> Bool {
        guard let detector = Self.addressDetector else { return false }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        var found = false
        detector.enumerateMatches(in: text, options: [], range: range) { m, _, stop in
            guard let m else { return }
            if m.resultType == .address {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
    
    // MARK: - Cleaning
    
    private func cleanAddressLine(_ s: String) -> String {
        var t = normalizeSpace(s)
        if t.isEmpty { return "" }
        t = stripWebLikeTokens(t)
        
        let rawSegments = t.split(whereSeparator: { $0 == "/" || $0 == "|" }).map(String.init)
        var kept: [String] = []
        
        for seg in rawSegments {
            let trimmed = normalizeSpace(seg)
            if trimmed.isEmpty { continue }
            if isPhoneNoteSegment(trimmed) { continue }
            if isBarePhoneLine(trimmed) { continue }
            
            var cleaned = stripLeadingPhoneLabelTokens(trimmed)
            cleaned = stripPhoneNotePhrases(cleaned)
            cleaned = normalizeSpace(cleaned)
            
            if cleaned.isEmpty { continue }
            if isAddressLabelOnly(cleaned) { continue }
            
            let lower = cleaned.lowercased()
            let hasDigits = cleaned.rangeOfCharacter(from: .decimalDigits) != nil
            if containsContactKeyword(lower) && !hasDigits
                && !looksLikeStateZipLine(cleaned)
                && !looksLikeAddressLine(cleaned) {
                continue
            }
            
            kept.append(cleaned)
        }
        
        return normalizeSpace(kept.joined(separator: " / "))
    }
    
    /// "John Smith 123 Main St" -> "123 Main St" when a two-word name precedes a numbered line.
    private func stripLeadingPersonNameFromAddressLine(_ s: String) -> String {
        let t = normalizeSpace(s)
        let parts = t.split(separator: " ")
        guard parts.count >= 3 else { return t }
        
        let first2 = parts.prefix(2).joined(separator: " ")
        let rest = parts.dropFirst(2).joined(separator: " ")
        
        let first2IsAlpha = first2.range(of: #"^[\p{L}\p{M}\.\-]+\s+[\p{L}\p{M}\.\-]+$"#, options: .regularExpression) != nil
        let restHasDigit = rest.rangeOfCharacter(from: .decimalDigits) != nil
        
        if first2IsAlpha && restHasDigit {
            return String(rest)
        }
        return t
    }
    
    private func stripWebLikeTokens(_ s: String) -> String {
        var t = s
        let patterns = [
            #"(https?://[^\s]+)"#,
            #"\bwww\.[A-Za-z0-9.\-]+\b"#,
            #"\b[A-Za-z0-9.\-]+\.(?:com|net|org|co|io|biz|us|info|tech|edu|gov|me|app)(?:\.[A-Za-z]{2})?\b"#
        ]
        for p in patterns {
            t = t.replacingOccurrences(of: p, with: "", options: .regularExpression)
        }
        return normalizeSpace(t)
    }
    
    private func stripLeadingPhoneLabelTokens(_ s: String) -> String {
        let t = normalizeSpace(s)
        guard !t.isEmpty else { return t }
        
        let labelWithPunct = #"^(tel|phone|ph|mobile|cell|direct|office|main|fax|t|m|d|p|c)\s*[:：\-]\s*"#
        if let range = t.range(of: labelWithPunct, options: [.regularExpression, .caseInsensitive]) {
            let rest = String(t[range.upperBound...])
            return normalizeSpace(rest)
        }
        
        let lower = t.lowercased()
        if let space = lower.firstIndex(of: " ") {
            let first = String(lower[..<space])
            let rest = String(t[t.index(after: space)...])
            let labels = Set(["main", "office", "direct", "mobile", "cell", "phone", "tel", "ph", "fax"])
            if labels.contains(first) {
                if first == "main" {
                    let restLower = rest.lowercased()
                    let streetLike = ["street", "st ", "st.", "road", "rd", "avenue", "ave", "drive", "dr",
                                      "lane", "ln", "boulevard", "blvd", "parkway", "pkwy", "way"]
                    if streetLike.contains(where: { restLower.hasPrefix($0) }) {
                        return t
                    }
                }
                return normalizeSpace(rest)
            }
        }
        
        return t
    }
    
    private func stripPhoneNotePhrases(_ s: String) -> String {
        var t = s
        let patterns = [
            #"\bfor\s+customer\s+service\b"#,
            #"\bcustomer\s+service\b"#,
            #"\btechnical\s+support\b"#,
            #"\btech\s+support\b"#,
            #"\bhelp\s+desk\b"#,
            #"\btoll[-\s]?free\b"#,
            #"\bcall\s+us\b"#,
            #"\bfor\s+service\b"#
        ]
        for p in patterns {
            t = t.replacingOccurrences(of: p, with: "", options: [.regularExpression, .caseInsensitive])
        }
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: " ,;/:-"))
        return normalizeSpace(t)
    }
    
    private func isPhoneNoteSegment(_ s: String) -> Bool {
        let lower = s.lowercased()
        let phrases = [
            "customer service",
            "technical support",
            "tech support",
            "help desk",
            "toll free",
            "call us"
        ]
        return phrases.contains(where: { lower.contains($0) })
    }
    
    private func unique(_ arr: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for s in arr {
            let key = normalizeKey(s)
            if seen.contains(key) { continue }
            seen.insert(key)
            out.append(normalizeSpace(s))
        }
        return out
    }
}
