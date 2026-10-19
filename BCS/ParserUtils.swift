import Foundation

func normalizeSpace(_ s: String) -> String {
    s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func normalizeKey(_ s: String) -> String {
    normalizeSpace(s).lowercased().replacingOccurrences(of: " ", with: "")
}

/// Matches keywords as whole words or phrases, never as substrings of other words,
/// so "web" does not hit "Weber" and "rep" does not hit "Repton".
/// A keyword matches when it is not immediately preceded or followed by a letter or digit,
/// which also lets punctuated keywords such as "dr.", "r&d", "e-mail" and "ext." work.
/// The regex is compiled once per matcher; keep matchers in `static let`/global constants.
struct KeywordMatcher {
    private let regex: NSRegularExpression?

    init(_ keywords: [String]) {
        // Longer alternatives first so "vice president" is preferred over "president".
        let alternatives = keywords
            .sorted { $0.count > $1.count }
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        regex = try? NSRegularExpression(
            pattern: #"(?<![\p{L}\p{N}])(?:"# + alternatives + #")(?![\p{L}\p{N}])"#,
            options: [.caseInsensitive]
        )
    }

    func matches(_ text: String) -> Bool {
        guard let regex else { return false }
        return regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }

    func hitCount(_ text: String) -> Int {
        guard let regex else { return 0 }
        return regex.numberOfMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }
}

private let jobTitleMatcher = KeywordMatcher([
    "engineer", "engineering", "developer", "sales", "marketing", "manager", "director", "president",
    "ceo", "cto", "cfo", "coo", "vp", "vice president", "founder", "owner", "partner", "chairman",
    "assistant", "representative", "rep", "account", "support", "office", "department", "division",
    "research", "r&d", "quality", "procurement", "purchasing", "chief", "leader", "supervisor",
    "phd", "dr.", "md", "mba"
])

func isJobTitleLine(_ lower: String) -> Bool {
    let hits = jobTitleMatcher.hitCount(lower)
    if hits >= 1 && lower.count <= 40 { return true }
    if hits >= 2 { return true }
    return false
}

private let contactKeywordMatcher = KeywordMatcher([
    "tel", "phone", "mobile", "cell", "fax", "facsimile", "e-mail", "email", "mail",
    "address", "web", "website", "http", "www", "office", "main", "direct", "ext.", "ext"
])

func containsContactKeyword(_ lower: String) -> Bool {
    contactKeywordMatcher.matches(lower)
}

/// "ACME ELECTRONICS": at least four letters and more than 90% of them upper case.
func isAllCapsLikeLogo(_ s: String) -> Bool {
    let letters = s.filter { $0.isLetter }
    guard letters.count >= 4 else { return false }
    let upper = letters.filter { String($0) == String($0).uppercased() }.count
    return Double(upper) / Double(letters.count) > 0.9
}

/// Two to four tokens made only of letters, marks, dots, apostrophes and hyphens: "John Smith", "Mary-Ann O'Neil".
func looksLikeEnglishPersonName(_ s: String) -> Bool {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    return t.range(of: #"^[\p{L}\p{M}\.'\-]+\s+[\p{L}\p{M}\.'\-]+(\s+[\p{L}\p{M}\.'\-]+){0,2}$"#,
                   options: .regularExpression) != nil
}
