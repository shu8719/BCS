import Foundation
import CoreGraphics


final class NameParser {
    func pickName(
        from lines: [OCRLine],
        email: String,
        company: String,
        address: String,
        looksLikeAddressLine: (String) -> Bool
    ) -> String {
        let emailName = nameFromEmail(email)
        
        if let strict = pickNameStrict(
            from: lines,
            email: email,
            company: company,
            address: address,
            looksLikeAddressLine: looksLikeAddressLine
        ), strict.count >= 3 {
            return cleanPersonName(strict, company: company)
        }
        
        if let loose = pickNameLoose(
            from: lines,
            email: email,
            company: company,
            address: address,
            looksLikeAddressLine: looksLikeAddressLine
        ), loose.count >= 2 {
            return cleanPersonName(loose, company: company)
        }
        
        return cleanPersonName(emailName, company: company)
    }
    
    func normalizeNameCompanyByEmailHints(_ result: inout BusinessCard, companyScore: (String) -> Int) {
        guard !result.email.isEmpty else { return }
        let hints = Set(nameHintsFromEmail(result.email))
        guard hints.count >= 2 else { return }
        
        func hitCount(_ s: String) -> Int {
            let tokens = normalizeSpace(s)
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
            return tokens.reduce(0) { $0 + (hints.contains($1) ? 1 : 0) }
        }
        
        let nameHits = hitCount(result.name)
        let companyHits = hitCount(result.company)
        let companyLooksPerson = looksLikeEnglishPersonName(result.company)
        let nameLooksCompany = companyScore(result.name) >= 4
        
        if (companyHits >= 2 && companyHits > nameHits && companyLooksPerson)
            || (nameLooksCompany && companyLooksPerson && companyHits > 0) {
            let oldName = result.name
            result.name = cleanPersonName(result.company, company: oldName)
            result.company = oldName
        } else {
            result.name = cleanPersonName(result.name, company: result.company)
        }
    }
    
    private func pickNameStrict(
        from lines: [OCRLine],
        email: String,
        company: String,
        address: String,
        looksLikeAddressLine: (String) -> Bool
    ) -> String? {
        let domainKey = domainKeyFromEmail(email)
        let emailHints = nameHintsFromEmail(email)
        
        func isBad(_ s: String) -> Bool {
            let t = normalizeSpace(s)
            let lower = t.lowercased()
            if t.isEmpty { return true }
            if t.count <= 3 && (t.contains(".") || t.contains("®") || t.contains("©")) { return true }
            if t == "Mr" || t == "Mr." || t == "Ms" || t == "Ms." || t == "Dr" || t == "Dr." { return true }
            if t.contains("@") || lower.contains("http") || lower.contains("www") { return true }
            if containsContactKeyword(lower) { return true }
            if looksLikeAddressLine(t) { return true }
            if !address.isEmpty, address.contains(t) { return true }
            if isJobTitleLine(lower) { return true }
            if looksLikeDepartmentLine(t) { return true }
            if !domainKey.isEmpty, lower.contains(domainKey.lowercased()) { return true }
            if !company.isEmpty, normalizeKey(t) == normalizeKey(company) { return true }
            if t.rangeOfCharacter(from: .decimalDigits) != nil { return true }
            return false
        }
        
        func score(_ line: OCRLine) -> Int {
            let t = normalizeSpace(line.text)
            if isBad(t) { return -10_000 }
            
            var sc = 0
            sc += Int(line.box.height * 1200)
            sc += Int(line.box.midY * 10)
            
            if looksLikeEnglishPersonName(t) { sc += 120 }
            if looksLikeAllCapsPersonName(t) { sc += 120 }
            if looksLikeTitleCasePersonName(t) { sc += 160 }

            let lower = t.lowercased()
            if emailHints.contains(where: { lower.contains($0) }) { sc += 40 }

            if isAllCapsLikeLogo(t) && !looksLikeAllCapsPersonName(t) { sc -= 420 }
            
            let wc = t.split(separator: " ").count
            if wc >= 5 { sc -= 120 }
            
            return sc
        }
        
        guard let best = lines.max(by: { score($0) < score($1) }) else { return nil }
        let s = normalizeSpace(best.text)
        return score(best) > 80 ? s : nil
    }
    
    private func pickNameLoose(
        from lines: [OCRLine],
        email: String,
        company: String,
        address: String,
        looksLikeAddressLine: (String) -> Bool
    ) -> String? {
        let domainKey = domainKeyFromEmail(email)
        let emailHints = nameHintsFromEmail(email)
        
        func isBadBase(_ s: String) -> Bool {
            let t = normalizeSpace(s)
            let lower = t.lowercased()
            if t.isEmpty { return true }
            if t.contains("@") || lower.contains("http") || lower.contains("www") { return true }
            if containsContactKeyword(lower) { return true }
            if looksLikeAddressLine(t) { return true }
            if !address.isEmpty, address.contains(t) { return true }
            if isJobTitleLine(lower) { return true }
            if looksLikeDepartmentLine(t) { return true }
            if !domainKey.isEmpty, lower.contains(domainKey.lowercased()) { return true }
            if !company.isEmpty, normalizeKey(t) == normalizeKey(company) { return true }
            return false
        }
        
        func extractNamePrefixIfMixed(_ s: String) -> String? {
            let t = normalizeSpace(s)
            guard let idx = t.firstIndex(where: { $0.isNumber }) else { return nil }
            let head = normalizeSpace(String(t[..<idx]))
            let tail = normalizeSpace(String(t[idx...]))
            if head.isEmpty || tail.isEmpty { return nil }
            if looksLikeAddressLine(tail) || tail.rangeOfCharacter(from: .decimalDigits) != nil {
                if looksLikeEnglishPersonName(head) {
                    return head
                }
            }
            return nil
        }
        
        func score(_ line: OCRLine) -> (Int, String) {
            let raw = normalizeSpace(line.text)
            if isBadBase(raw) { return (-10_000, "") }
            
            let candidate = extractNamePrefixIfMixed(raw) ?? raw
            let cand = normalizeSpace(candidate)
            if cand.isEmpty { return (-10_000, "") }
            if cand.rangeOfCharacter(from: .decimalDigits) != nil { return (-10_000, "") }
            
            let lower = cand.lowercased()
            var sc = 0
            sc += Int(line.box.height * 1000)
            sc += Int(line.box.midY * 8)
            
            if looksLikeEnglishPersonName(cand) { sc += 80 }
            if looksLikeAllCapsPersonName(cand) { sc += 100 }
            if looksLikeTitleCasePersonName(cand) { sc += 140 }

            if emailHints.contains(where: { lower.contains($0) }) { sc += 40 }
            if cand.count <= 3 { sc -= 80 }

            if isAllCapsLikeLogo(cand) && !looksLikeAllCapsPersonName(cand) { sc -= 360 }
            
            return (sc, cand)
        }
        
        let scored = lines.map(score).sorted { $0.0 > $1.0 }
        guard let best = scored.first, best.0 > 30, !best.1.isEmpty else { return nil }
        return best.1
    }
    
    private func looksLikeEnglishPersonName(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.range(of: #"^[\p{L}\p{M}\.'\-]+\s+[\p{L}\p{M}\.'\-]+(\s+[\p{L}\p{M}\.'\-]+){0,2}$"#,
                       options: .regularExpression) != nil
    }
    
    private func looksLikeTitleCasePersonName(_ s: String) -> Bool {
        let t = normalizeSpace(s)
        let tokens = t.split(separator: " ").map(String.init)
        guard (2...4).contains(tokens.count) else { return false }
        
        for tok in tokens {
            guard tok.count >= 2 else { return false }
            
            // 文字が全く無いトークンはNG
            if tok.range(of: #"[A-Za-zÀ-ÖØ-öø-ÿ]"#, options: .regularExpression) == nil {
                return false
            }
            
            // 先頭大文字
            let first = tok.prefix(1)
            if first.uppercased() != first { return false }
            
            // 全大文字はTitleCase扱いしない（ALL CAPS対策）
            if tok.uppercased() == tok { return false }
            
            // 残りは小文字想定（アクセント含む）
            let rest = tok.dropFirst()
            if rest.lowercased() != rest { return false }
        }
        return true
    }
    
    private func looksLikeAllCapsPersonName(_ s: String) -> Bool {
        let t = normalizeSpace(s)
        let tokens = t.split(separator: " ").map(String.init)
        guard (2...4).contains(tokens.count) else { return false }
        
        let blocked = Set([
            "INC", "LLC", "LTD", "CORP", "CO", "GMBH", "KFT", "AG", "KG", "BV", "SA", "SAS", "SRL", "OY", "AB",
            "STREET", "ROAD", "AVENUE", "DRIVE", "SUITE", "BUILDING", "CENTER", "OFFICE"
        ])
        if tokens.contains(where: { blocked.contains($0.uppercased()) }) { return false }
        
        for token in tokens {
            let letters = token.filter { $0.isLetter }
            guard letters.count >= 2 else { return false }
            if letters.uppercased() != letters { return false }
        }
        
        return true
    }
    
    private func looksLikeDepartmentLine(_ s: String) -> Bool {
        let lower = normalizeSpace(s).lowercased()
        let keys = [
            "product development",
            "product engineering",
            "product management",
            "customer service",
            "technical support"
        ]
        return keys.contains(where: { lower.contains($0) })
    }
    
    private func isAllCapsLikeLogo(_ s: String) -> Bool {
        let letters = s.filter { $0.isLetter }
        guard letters.count >= 4 else { return false }
        let upper = letters.filter { String($0) == String($0).uppercased() }.count
        return Double(upper) / Double(letters.count) > 0.9
    }
    
    private func domainKeyFromEmail(_ email: String) -> String {
        guard let at = email.firstIndex(of: "@") else { return "" }
        let afterAt = email.index(after: at)
        let domainPart = String(email[afterAt...])
        guard let dot = domainPart.firstIndex(of: ".") else { return "" }
        return String(domainPart[..<dot])
    }
    
    private func nameFromEmail(_ email: String) -> String {
        guard let at = email.firstIndex(of: "@") else { return "" }
        let local = email[..<at]
        let parts = local
            .replacingOccurrences(of: "_", with: ".")
            .replacingOccurrences(of: "-", with: ".")
            .split(separator: ".")
            .map(String.init)
            .filter { !$0.isEmpty }
        
        let capped = parts.map { p -> String in
            if p.count == 1 { return p.uppercased() }
            return p.prefix(1).uppercased() + p.dropFirst().lowercased()
        }
        
        return capped.count >= 2 ? capped.joined(separator: " ") : ""
    }
    
    private func nameHintsFromEmail(_ email: String) -> [String] {
        guard let at = email.firstIndex(of: "@") else { return [] }
        let local = String(email[..<at]).lowercased()
        let parts = local
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 2 }
        return Array(Set(parts))
    }
    
    private func cleanPersonName(_ name: String, company: String) -> String {
        let raw = normalizeSpace(name)
        guard !raw.isEmpty else { return "" }
        let parts = raw.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return raw }
        
        let blockedCommon = Set([
            "inc", "llc", "ltd", "corp", "company", "co", "gmbh", "kft", "ag", "sa", "group",
            "electronics", "assembly", "solutions", "systems", "manager", "director", "engineer",
            "sales", "marketing", "office", "department", "division", "team", "future",
            "service", "services", "technology", "technologies", "development", "project", "kuiper"
        ])
        let companyTokens = Set(
            normalizeKey(company)
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
                .filter { $0.count >= 2 }
        )
        
        var kept: [String] = []
        for p in parts {
            let key = normalizeKey(p)
            if key.isEmpty { continue }
            if blockedCommon.contains(key) { continue }
            if companyTokens.contains(key) { continue }
            kept.append(p)
        }
        
        if kept.count >= 2 { return kept.joined(separator: " ") }
        return parts.prefix(2).joined(separator: " ")
    }
    
}
