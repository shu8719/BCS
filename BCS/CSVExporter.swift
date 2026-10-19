import Foundation

/// Builds the CSV that "Export CSV" shares: RFC 4180 escaping, UTF-8 BOM and CRLF so Excel and Numbers open it cleanly.
enum CSVExporter {
    static func makeCSV(cards: [BusinessCard], lang: AppSettings.Language) -> String {
        let headers = [L10n.t(.name, lang: lang), L10n.t(.company, lang: lang),
                       L10n.t(.address, lang: lang), L10n.t(.phone, lang: lang),
                       L10n.t(.email, lang: lang), L10n.t(.timeZone, lang: lang)]
        var rows = [headers.map(escape).joined(separator: ",")]
        for c in cards {
            let phones = c.phones.map(\.number).joined(separator: " / ")
            rows.append([c.name, c.company, c.address, phones, c.email, c.timeZoneCode]
                .map(escape).joined(separator: ","))
        }
        return "\u{FEFF}" + rows.joined(separator: "\r\n")
    }
    
    /// Writes the CSV to the temporary directory; the caller shares and then deletes it.
    static func writeTemporaryFile(cards: [BusinessCard], lang: AppSettings.Language) throws -> URL {
        let fileName = "business_cards_\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try makeCSV(cards: cards, lang: lang).write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    nonisolated private static func escape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }
}
