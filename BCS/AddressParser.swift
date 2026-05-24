import Foundation
import CoreGraphics

final class AddressParser {
    func pickAddressBlockInfo(from lines: [OCRLine]) -> (text: String, box: CGRect?) {
        guard !lines.isEmpty else { return ("", nil) }
        
        let ordered = lines.sorted { $0.box.midY > $1.box.midY }
        let strongIndices = ordered.indices.filter { looksLikeAddressLine(ordered[$0].text) }
        
        if strongIndices.isEmpty {
            let fallback = detectAddressFallback(from: ordered.map(\.text).joined(separator: "\n"))
            return (fallback, nil)
        }
        
        let medianHeight = median(ordered.map(\.box.height))
        let yThreshold = max(0.012, medianHeight * 1.8)
        let alignMidXThreshold: CGFloat = 0.18
        let overlapThreshold: CGFloat = 0.25
        
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
                if isJoinable(line, anchor) && looksLikeAddressContinuation(line.text) {
                    block.insert(line, at: 0)
                    used.insert(i)
                    anchor = line
                } else if abs(line.box.midY - anchor.box.midY) > yThreshold * 1.8 {
                    break
                }
                i -= 1
            }
            
            var j = idx + 1
            anchor = ordered[idx]
            while j < ordered.count {
                let line = ordered[j]
                if isJoinable(line, anchor) && looksLikeAddressContinuation(line.text) {
                    block.append(line)
                    used.insert(j)
                    anchor = line
                } else if abs(line.box.midY - anchor.box.midY) > yThreshold * 1.8 {
                    break
                }
                j += 1
            }
            
            blocks.append(block)
        }
        
        func blockBox(_ block: [OCRLine]) -> CGRect {
            block.map(\.box).reduce(block[0].box) { $0.union($1) }
        }
        
        let sortedBlocks = blocks.sorted { blockBox($0).midY > blockBox($1).midY }
        var merged: [[OCRLine]] = []
        for block in sortedBlocks {
            if let last = merged.last {
                let lastBox = blockBox(last)
                let box = blockBox(block)
                let verticalGap = abs(lastBox.minY - box.maxY)
                if verticalGap <= yThreshold * 1.6 && isAligned(lastBox, box) {
                    merged[merged.count - 1].append(contentsOf: block)
                    continue
                }
            }
            merged.append(block)
        }
        
        func blockScore(_ block: [OCRLine]) -> Int {
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
        
        let best = merged.max(by: { blockScore($0) < blockScore($1) }) ?? merged[0]
        var orderedBest = best.sorted { $0.box.midY > $1.box.midY }
        
        // If the chosen block is missing an indented continuation line just below it,
        // pull in the nearest address-like line even when alignment checks failed.
        func isSameLine(_ a: OCRLine, _ b: OCRLine) -> Bool {
            a.text == b.text && a.box == b.box
        }
        
        if let bottom = orderedBest.last {
            let candidates = ordered
                .filter { $0.box.midY < bottom.box.midY }
                .map { line -> (OCRLine, CGFloat) in
                    let gap = abs(bottom.box.minY - line.box.maxY)
                    return (line, gap)
                }
                .sorted { $0.1 < $1.1 }
            
            if let pick = candidates.first(where: { line, gap in
                if gap > yThreshold * 2.2 { return false }
                if isSameLine(line, bottom) { return false }
                if orderedBest.contains(where: { isSameLine($0, line) }) { return false }
                let t = normalizeSpace(line.text)
                if t.isEmpty || isAddressLabelOnly(t) { return false }
                return looksLikeAddressContinuation(t) || looksLikeStateZipLine(t)
            }) {
                orderedBest.append(pick.0)
                orderedBest = orderedBest.sorted { $0.box.midY > $1.box.midY }
            }
        }
        
        if let top = orderedBest.first {
            let candidates = ordered
                .filter { $0.box.midY > top.box.midY }
                .map { line -> (OCRLine, CGFloat) in
                    let gap = abs(line.box.minY - top.box.maxY)
                    return (line, gap)
                }
                .sorted { $0.1 < $1.1 }
            
            if let pick = candidates.first(where: { line, gap in
                if gap > yThreshold * 3.0 { return false }
                if orderedBest.contains(where: { isSameLine($0, line) }) { return false }
                let t = normalizeSpace(line.text)
                if t.isEmpty || isAddressLabelOnly(t) { return false }
                return looksLikeAddressLine(t) || looksLikeStateZipLine(t)
            }) {
                orderedBest.append(pick.0)
                orderedBest = orderedBest.sorted { $0.box.midY > $1.box.midY }
            }
        }
        
        let cleaned = orderedBest
            .map { cleanAddressLine($0.text) }
            .filter { !$0.isEmpty }
            .map { stripLeadingPersonNameFromAddressLine($0) }
            .filter { !$0.isEmpty && !isAddressLabelOnly($0) }
        
        let text = unique(cleaned).joined(separator: " / ")
        if text.isEmpty {
            let fallback = detectAddressFallback(from: ordered.map(\.text).joined(separator: "\n"))
            return (fallback, nil)
        }
        
        let box = orderedBest.map(\.box).reduce(orderedBest[0].box) { $0.union($1) }
        return (text, box)
    }
    
    func isWeakAddress(_ s: String) -> Bool {
        let t = normalizeSpace(s)
        return t.isEmpty || isAddressLabelOnly(t) || t.count <= 8
    }
    
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
    
    func looksLikeAddressLine(_ line: String) -> Bool {
        let t = normalizeSpace(line)
        let lower = t.lowercased()
        
        if t.isEmpty { return false }
        if isAddressLabelOnly(t) { return false }
        if isPhoneContactLine(t) { return false }
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
    
    private func detectAddressFallback(from text: String) -> String {
        guard !text.isEmpty else { return "" }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue) else {
            return ""
        }
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
    
    private func median(_ values: [CGFloat]) -> CGFloat {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
    
    private func isContactLine(_ lower: String) -> Bool {
        let keys = ["tel", "phone", "mobile", "cell", "fax", "facsimile", "e-mail", "email", "mail", "web", "website", "http", "www"]
        return keys.contains(where: { lower.contains($0) })
    }
    
    private func matchesAddressDetector(_ text: String) -> Bool {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue) else {
            return false
        }
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
    
    private func looksLikeAddressContinuation(_ line: String) -> Bool {
        let t = normalizeSpace(line)
        let lower = t.lowercased()
        
        if t.isEmpty { return false }
        if isPhoneContactLine(t) { return false }
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
    
    private func looksLikeAddressWordLine(_ line: String) -> Bool {
        let t = normalizeSpace(line)
        let lower = t.lowercased()
        
        if t.rangeOfCharacter(from: .decimalDigits) != nil || t.contains(",") { return true }
        
        let suffixes = ["street", "st", "road", "rd", "avenue", "ave", "drive", "dr", "suite", "floor", "building"]
        if suffixes.contains(where: { lower.contains($0) }) { return true }
        
        let tokens = t.split(separator: " ")
        if (1...3).contains(tokens.count) {
            let letters = t.filter { $0.isLetter }
            if !letters.isEmpty && letters.uppercased() == letters { return true }
        }
        
        return false
    }
    
    private func looksLikeEnglishPersonName(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.range(of: #"^[\p{L}\p{M}\.'\-]+\s+[\p{L}\p{M}\.'\-]+(\s+[\p{L}\p{M}\.'\-]+){0,2}$"#, options: .regularExpression) != nil
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
        let hasPhoneWord = ["tel", "phone", "mobile", "cell", "office", "direct", "main"].contains(where: { lower.contains($0) })
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
    
    private func containsAddressLabelKeyword(_ s: String) -> Bool {
        let t = normalizeSpace(s).lowercased()
        let keys = ["address", "office address", "location", "head office", "addr"]
        return keys.contains(where: { t.contains($0) })
    }
    
    private func looksLikeStateZipLine(_ s: String) -> Bool {
        let t = normalizeSpace(s)
        if t.range(of: #"\b[A-Z]{2}\s+\d{5}(?:-\d{4})?\b"#, options: .regularExpression) != nil { return true }
        if t.range(of: #"\b\d{5}(?:-\d{4})?\b"#, options: .regularExpression) != nil && t.contains(",") { return true }
        return false
    }
    

    
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

