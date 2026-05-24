import Foundation

let usStateCodes: Set<String> = [
    "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA","KS","KY","LA","ME","MD",
    "MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA","RI","SC",
    "SD","TN","TX","UT","VT","VA","WA","WV","WI","WY","DC"
]

struct BusinessCard: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var company: String = ""
    var phones: [LabeledNumber] = []
    var email: String = ""
    var address: String = ""
    var timeZoneCode: String = ""
    var timeZoneId: String = ""
    var timeZoneSourceAddress: String = ""
}

enum PhoneLabel: String, CaseIterable, Identifiable, Codable {
    case direct
    case main
    case mobile
    case unknown
    
    var id: String { rawValue }
}

struct LabeledNumber: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var label: PhoneLabel
    var number: String
}

fileprivate func parseCSVLine(_ line: String) -> [String] {
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

final class ZipTimeZoneDB {
    static let shared = ZipTimeZoneDB()
    
    private let queue = DispatchQueue(label: "ZipTimeZoneDB")
    private var map: [String: String] = [:]
    private var loaded = false
    
    private init() {}
    
    func preload() {
        queue.async { [weak self] in
            self?.loadIfNeeded()
        }
    }
    
    func timeZoneIdentifier(for zip: String) -> String? {
        queue.sync {
            loadIfNeeded()
            return map[zip]
        }
    }
    
    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        
        guard let url = Bundle.main.url(forResource: "uszips", withExtension: "csv"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }
        
        let lines = contents.split(whereSeparator: \.isNewline)
        guard let headerLine = lines.first else { return }
        
        let headers = parseCSVLine(String(headerLine))
        guard let zipIndex = headers.firstIndex(of: "zip"),
              let tzIndex = headers.firstIndex(of: "timezone") else {
            return
        }
        
        var tmp: [String: String] = [:]
        for line in lines.dropFirst() {
            let fields = parseCSVLine(String(line))
            if fields.count <= max(zipIndex, tzIndex) { continue }
            let zip = fields[zipIndex]
            let tz = fields[tzIndex]
            if zip.count == 5, !tz.isEmpty {
                tmp[zip] = tz
            }
        }
        
        map = tmp
    }
}

final class AreaCodeTimeZoneDB {
    static let shared = AreaCodeTimeZoneDB()
    
    private let queue = DispatchQueue(label: "AreaCodeTimeZoneDB")
    private var map: [String: String] = [:]
    private var loaded = false
    
    private init() {}
    
    func preload() {
        queue.async { [weak self] in
            self?.loadIfNeeded()
        }
    }
    
    func timeZoneIdentifier(for areaCode: String) -> String? {
        queue.sync {
            loadIfNeeded()
            return map[areaCode]
        }
    }
    
    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        
        guard let url = Bundle.main.url(forResource: "ac-tz", withExtension: "csv"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }
        
        let lines = contents.split(whereSeparator: \.isNewline)
        guard let headerLine = lines.first else { return }
        
        let headers = parseCSVLine(String(headerLine))
        guard let acIndex = headers.firstIndex(of: "area_code"),
              let regionIndex = headers.firstIndex(of: "region"),
              let tzIndex = headers.firstIndex(of: "zone_name"),
              let multiIndex = headers.firstIndex(of: "multi_timezone") else {
            return
        }
        
        var tmp: [String: String] = [:]
        for line in lines.dropFirst() {
            let fields = parseCSVLine(String(line))
            if fields.count <= max(acIndex, max(regionIndex, max(tzIndex, multiIndex))) { continue }
            let area = fields[acIndex]
            let region = fields[regionIndex]
            let tz = fields[tzIndex]
            let multi = fields[multiIndex].lowercased()
            if !usStateCodes.contains(region) { continue }
            if multi == "true" { continue }
            if area.count == 3, !tz.isEmpty {
                tmp[area] = tz
            }
        }
        
        map = tmp
    }
}

