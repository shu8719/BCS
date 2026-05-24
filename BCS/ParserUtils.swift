import Foundation

func normalizeSpace(_ s: String) -> String {
    s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func normalizeKey(_ s: String) -> String {
    normalizeSpace(s).lowercased().replacingOccurrences(of: " ", with: "")
}

private let jobTitleWords: [String] = [
    "engineer", "engineering", "developer", "sales", "marketing", "manager", "director", "president",
    "ceo", "cto", "cfo", "coo", "vp", "vice president", "founder", "owner", "partner", "chairman",
    "assistant", "representative", "rep", "account", "support", "office", "department", "division",
    "research", "r&d", "quality", "procurement", "purchasing", "chief", "leader", "supervisor",
    "phd", "dr.", "md", "mba"
]

func isJobTitleLine(_ lower: String) -> Bool {
    let hits = jobTitleWords.filter { lower.contains($0) }.count
    if hits >= 1 && lower.count <= 40 { return true }
    if hits >= 2 { return true }
    return false
}

private let contactKeywords: [String] = [
    "tel", "phone", "mobile", "cell", "fax", "facsimile", "e-mail", "email", "mail",
    "address", "web", "website", "http", "www", "office", "main", "direct", "ext.", "ext"
]

func containsContactKeyword(_ lower: String) -> Bool {
    contactKeywords.contains(where: { lower.contains($0) })
}
