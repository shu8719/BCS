import Foundation

/// A lazily loaded, thread-safe key -> IANA time zone table backed by a CSV file.
/// Used for the ZIP table (uszips.csv) and the area-code table (ac-tz.csv).
final class TimeZoneLookupTable {
    typealias Row = [String: String]
    
    // MARK: - Bundled tables
    
    static let bundledZip = zip(fileURL: Bundle.main.url(forResource: "uszips", withExtension: "csv"))
    static let bundledAreaCode = areaCode(fileURL: Bundle.main.url(forResource: "ac-tz", withExtension: "csv"))
    
    /// 5-digit ZIP -> time zone.
    static func zip(fileURL: URL?) -> TimeZoneLookupTable {
        TimeZoneLookupTable(name: "uszips.csv", fileURL: fileURL, keyColumn: "zip", valueColumn: "timezone") { row in
            row["zip"]?.count == 5
        }
    }
    
    /// 3-digit US area code -> time zone. Skips non-US regions and codes that span several zones.
    static func areaCode(fileURL: URL?) -> TimeZoneLookupTable {
        TimeZoneLookupTable(name: "ac-tz.csv", fileURL: fileURL, keyColumn: "area_code", valueColumn: "zone_name") { row in
            guard let region = row["region"], usStateCodes.contains(region) else { return false }
            if row["multi_timezone"]?.lowercased() == "true" { return false }
            return row["area_code"]?.count == 3
        }
    }
    
    // MARK: - Instance
    
    private let name: String
    private let fileURL: URL?
    private let keyColumn: String
    private let valueColumn: String
    private let includeRow: (Row) -> Bool
    
    private let queue: DispatchQueue
    private var map: [String: String] = [:]
    private var loaded = false
    
    init(name: String, fileURL: URL?, keyColumn: String, valueColumn: String, includeRow: @escaping (Row) -> Bool) {
        self.name = name
        self.fileURL = fileURL
        self.keyColumn = keyColumn
        self.valueColumn = valueColumn
        self.includeRow = includeRow
        self.queue = DispatchQueue(label: "TimeZoneLookupTable.\(name)")
    }
    
    /// Starts loading in the background so the first lookup does not pay for parsing.
    func preload() {
        queue.async { [weak self] in
            self?.loadIfNeeded()
        }
    }
    
    func timeZoneIdentifier(for key: String) -> String? {
        queue.sync {
            loadIfNeeded()
            return map[key]
        }
    }
    
    var entryCount: Int {
        queue.sync {
            loadIfNeeded()
            return map.count
        }
    }
    
    // MARK: - Loading
    
    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        
        guard let url = fileURL,
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            print("TimeZoneLookupTable: could not load \(name)")
            return
        }
        
        let lines = contents.split(whereSeparator: \.isNewline)
        guard let headerLine = lines.first else { return }
        let headers = Self.parseCSVLine(String(headerLine))
        guard let keyIndex = headers.firstIndex(of: keyColumn),
              let valueIndex = headers.firstIndex(of: valueColumn) else {
            print("TimeZoneLookupTable: \(name) is missing column \(keyColumn) or \(valueColumn)")
            return
        }
        
        var tmp: [String: String] = [:]
        for line in lines.dropFirst() {
            let fields = Self.parseCSVLine(String(line))
            guard fields.count > max(keyIndex, valueIndex) else { continue }
            let value = fields[valueIndex]
            guard !value.isEmpty else { continue }
            
            var row: Row = [:]
            for (i, header) in headers.enumerated() where i < fields.count {
                row[header] = fields[i]
            }
            guard includeRow(row) else { continue }
            tmp[fields[keyIndex]] = value
        }
        map = tmp
    }
    
    /// Minimal RFC 4180 field splitting (quotes and doubled quotes).
    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var field = ""
        var inQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let c = line[i]
            if c == "\"" {
                let next = line.index(after: i)
                if inQuotes && next < line.endIndex && line[next] == "\"" {
                    field.append("\"")
                    i = next
                } else {
                    inQuotes.toggle()
                }
            } else if c == "," && !inQuotes {
                result.append(field)
                field = ""
            } else {
                field.append(c)
            }
            i = line.index(after: i)
        }
        
        result.append(field)
        return result
    }
}
