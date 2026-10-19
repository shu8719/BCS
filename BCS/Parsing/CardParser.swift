import Foundation
import CoreGraphics

/// Turns raw OCR fragments into a `BusinessCard`.
/// Pure Foundation: shared by the camera scanner, the DEBUG photo import and the fixture tests.
final class CardParser {
    private let phoneParser = PhoneParser()
    private let addressParser = AddressParser()
    private let nameParser = NameParser()
    
    private static let emailRegex = try? NSRegularExpression(
        pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
        options: [.caseInsensitive]
    )
    
    func parse(items: [OCRItem]) -> BusinessCard {
        let lines = buildLines(from: items)
        let texts = lines.map(\.text)
        
        let email = texts.compactMap(extractEmail).first ?? ""
        var company = pickCompany(from: texts, email: email)
        
        let addressInfo = addressParser.pickAddressBlockInfo(from: lines)
        let addrExtract = phoneParser.extractPhonesFromAddressText(addressInfo.text)
        var address = addrExtract.cleanAddress
        
        // Try a second-pass recovery for multi-line addresses.
        let recovered = addressParser.recoverAddress(from: lines)
        if !recovered.isEmpty {
            let recoveredClean = phoneParser.extractPhonesFromAddressText(recovered).cleanAddress
            if isBetterAddressCandidate(recoveredClean, than: address) {
                address = recoveredClean
            }
        }
        
        let phonesFromLines = phoneParser.extractPhones(from: lines)
        let phonesFromAll = phoneParser.extractPhonesFromWholeText(lines: lines)
        let phones = phoneParser.dedupePhones(phonesFromLines + addrExtract.phones + phonesFromAll)
        
        var name = nameParser.pickName(
            from: lines,
            email: email,
            company: company,
            address: address,
            looksLikeAddressLine: addressParser.looksLikeAddressLine
        )
        nameParser.normalizeNameCompanyByEmailHints(name: &name, company: &company, email: email, companyScore: companyScore)
        
        var result = BusinessCard()
        result.name = ContactField(name)
        result.company = ContactField(company)
        result.phones = phones
        result.email = ContactField(email)
        result.address = ContactField(address)
        ReviewFlagger.apply(to: &result)
        return result
    }
    
    /// Groups fragments into rows by Y, then splits each row into columns where a large horizontal gap appears.
    func buildLines(from items: [OCRItem]) -> [OCRLine] {
        let sorted = items.sorted {
            if abs($0.box.midY - $1.box.midY) > 0.01 {
                return $0.box.midY > $1.box.midY
            }
            return $0.box.minX < $1.box.minX
        }
        
        var rows: [[OCRItem]] = []
        let yThreshold: CGFloat = 0.02
        
        for it in sorted {
            if let last = rows.last, let rep = last.first {
                let dy = abs(rep.box.midY - it.box.midY)
                if dy < yThreshold {
                    rows[rows.count - 1].append(it)
                } else {
                    rows.append([it])
                }
            } else {
                rows.append([it])
            }
        }
        
        func isLikelyNewColumn(prev: OCRItem, next: OCRItem) -> Bool {
            let gap = next.box.minX - prev.box.maxX
            let base = max(prev.box.width, next.box.width)
            // A new column starts when the gap dwarfs the fragments themselves, or when it is
            // clearly wider than the text height (a space between words is only a fraction of it).
            let lineHeight = (prev.box.height + next.box.height) / 2
            return gap > base * 1.2 || gap > lineHeight * 1.5
        }
        
        var lines: [OCRLine] = []
        for row in rows {
            let r = row.sorted { $0.box.minX < $1.box.minX }
            var segments: [[OCRItem]] = []
            var current: [OCRItem] = []
            
            for it in r {
                if current.isEmpty {
                    current = [it]
                    continue
                }
                let prev = current.last!
                if isLikelyNewColumn(prev: prev, next: it) {
                    segments.append(current)
                    current = [it]
                } else {
                    current.append(it)
                }
            }
            if !current.isEmpty { segments.append(current) }
            
            for seg in segments {
                let text = seg.map { $0.text }.joined(separator: " ")
                let box = seg.map(\.box).reduce(seg[0].box) { $0.union($1) }
                lines.append(OCRLine(text: normalizeSpace(text), box: box))
            }
        }
        
        return lines
    }
    
    // MARK: - Email / company
    
    private func extractEmail(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let ns = t as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let m = Self.emailRegex?.firstMatch(in: t, range: range) else { return nil }
        return ns.substring(with: m.range)
    }
    
    private func pickCompany(from texts: [String], email: String) -> String {
        let pool = texts.filter { !isJunkForCompany($0) }
        let scored = pool.map { t -> (String, Int) in (t, companyScore(t)) }
        
        if let best = scored.max(by: { $0.1 < $1.1 }), best.1 >= 4 {
            return best.0
        }
        
        if !email.isEmpty { return companyFromEmail(email) }
        return ""
    }
    
    private func companyScore(_ s: String) -> Int {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = t.lowercased()
        
        if lower.contains("@") || lower.contains("http") || lower.contains("www") { return -100 }
        if containsContactKeyword(lower) { return -100 }
        if isJobTitleLine(lower) { return -60 }
        if addressParser.looksLikeAddressLine(t) { return -80 }
        if t.range(of: #"[A-Za-z\.\s]+,\s*[A-Z]{2}\s*\d{5}(?:-\d{4})?"#, options: .regularExpression) != nil {
            return -80
        }
        
        var score = 0
        if t.range(of: #"(Inc\.?|LLC|Ltd\.?|Corp\.?|GmbH|Kft\.?|Co\.?,?\s*Ltd\.?)"#,
                   options: [.regularExpression, .caseInsensitive]) != nil {
            score += 8
        }
        if (3...70).contains(t.count) { score += 2 }
        
        if isAllCapsLikeLogo(t) { score -= 2 }
        return score
    }
    
    private func isJunkForCompany(_ s: String) -> Bool {
        let l = s.lowercased()
        return l.contains("@") || l.contains("http") || l.contains("www") || containsContactKeyword(l)
    }
    
    private func companyFromEmail(_ email: String) -> String {
        guard let at = email.firstIndex(of: "@") else { return "" }
        let domain = String(email[email.index(after: at)...])
        let key = domain.split(separator: ".").first.map(String.init) ?? ""
        if key.isEmpty { return "" }
        return key.prefix(1).uppercased() + key.dropFirst()
    }
    
    // MARK: - Address choice
    
    private func isBetterAddressCandidate(_ candidate: String, than current: String) -> Bool {
        let c = normalizeSpace(candidate)
        let cur = normalizeSpace(current)
        if c.isEmpty { return false }
        if cur.isEmpty { return true }
        if c == cur { return false }
        
        func score(_ s: String) -> Int {
            var sc = 0
            let segments = s.split(separator: "/").count
            sc += segments * 15
            
            if s.range(of: #"\b[A-Z]{2}\s+\d{5}(?:-\d{4})?\b"#, options: .regularExpression) != nil { sc += 20 }
            if s.range(of: #"\b\d{5}(?:-\d{4})?\b"#, options: .regularExpression) != nil { sc += 12 }
            if s.contains(",") { sc += 8 }
            if s.range(of: #"^\d{1,5}\s+\p{L}{2,}"#, options: .regularExpression) != nil { sc += 10 }
            if s.range(of: #"\b(street|st\.?|road|rd\.?|avenue|ave\.?|drive|dr\.?|suite|ste\.?|building|bldg\.?)\b"#,
                       options: [.regularExpression, .caseInsensitive]) != nil { sc += 10 }
            sc += min(20, s.count / 10)
            
            return sc
        }
        
        return score(c) > score(cur)
    }
}
