import Foundation

let usStateCodes: Set<String> = [
    "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA","HI","ID","IL","IN","IA","KS","KY","LA","ME","MD",
    "MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA","RI","SC",
    "SD","TN","TX","UT","VT","VA","WA","WV","WI","WY","DC"
]

// MARK: - Review state

/// Why a field is marked "要確認". Set by the parser / resolver only (spec §4); the UI never decides this.
enum ReviewReason: String, Codable, Equatable {
    case normalized        // formatting was corrected, original kept in rawValue
    case missing           // name or company could not be read
    case timeZoneConflict  // ZIP and area code disagree
}

/// One contact value plus its OCR origin and review state.
struct ContactField: Codable, Equatable, ExpressibleByStringLiteral {
    var value: String
    /// The OCR text before correction. nil when nothing was corrected.
    var rawValue: String?
    var reviewReason: ReviewReason?
    
    var needsReview: Bool { reviewReason != nil }
    var isEmpty: Bool { value.isEmpty }
    
    init(_ value: String = "", rawValue: String? = nil, reviewReason: ReviewReason? = nil) {
        self.value = value
        self.rawValue = rawValue
        self.reviewReason = reviewReason
    }
    
    init(stringLiteral value: String) {
        self.init(value)
    }
    
    mutating func markReviewed() {
        reviewReason = nil
    }
    
    private enum CodingKeys: String, CodingKey { case value, rawValue, reviewReason }
    
    /// Accepts a bare JSON string (files written before review state existed) or an object.
    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let s = try? single.decode(String.self) {
            value = s
            rawValue = nil
            reviewReason = nil
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        value = try c.decodeIfPresent(String.self, forKey: .value) ?? ""
        rawValue = try c.decodeIfPresent(String.self, forKey: .rawValue)
        reviewReason = (try? c.decodeIfPresent(ReviewReason.self, forKey: .reviewReason)) ?? nil
    }
}

// MARK: - Phones

enum PhoneLabel: String, CaseIterable, Identifiable, Codable {
    case direct
    case main
    case mobile
    case unknown
    
    var id: String { rawValue }
}

struct LabeledNumber: Identifiable, Equatable, Codable {
    var id: UUID
    var label: PhoneLabel
    var field: ContactField
    
    /// Alias of `field.value`, kept so parser and export code read naturally.
    var number: String {
        get { field.value }
        set { field.value = newValue }
    }
    
    init(id: UUID = UUID(), label: PhoneLabel, number: String) {
        self.init(id: id, label: label, field: ContactField(number))
    }
    
    init(id: UUID = UUID(), label: PhoneLabel, field: ContactField) {
        self.id = id
        self.label = label
        self.field = field
    }
    
    private enum CodingKeys: String, CodingKey { case id, label, field, number }
    
    /// Accepts v1 `{id, label, number}` and v2 `{id, label, field}`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        label = try c.decodeIfPresent(PhoneLabel.self, forKey: .label) ?? .unknown
        if let f = try c.decodeIfPresent(ContactField.self, forKey: .field) {
            field = f
        } else {
            field = ContactField(try c.decodeIfPresent(String.self, forKey: .number) ?? "")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(label, forKey: .label)
        try c.encode(field, forKey: .field)
    }
}

// MARK: - Time zone

enum USTimeZone: String, Codable, CaseIterable, Equatable {
    case est = "EST"
    case cst = "CST"
    case mst = "MST"
    case pst = "PST"
    
    /// Used only when a card has a zone but no IANA identifier.
    var representativeIdentifier: String {
        switch self {
        case .est: return "America/New_York"
        case .cst: return "America/Chicago"
        case .mst: return "America/Denver"
        case .pst: return "America/Los_Angeles"
        }
    }
}

/// How the time zone was determined.
enum TimeZoneSource: Codable, Equatable {
    case zip(String)
    case areaCode(String)
    case manual
    
    /// v1 files stored "95110", "AC:415" or "" in `timeZoneSourceAddress`.
    init?(legacySourceKey key: String) {
        if key.hasPrefix("AC:") {
            self = .areaCode(String(key.dropFirst(3)))
        } else if key.count == 5, key.allSatisfy(\.isNumber) {
            self = .zip(key)
        } else {
            return nil
        }
    }
    
    private enum CodingKeys: String, CodingKey { case kind, value }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        let value = try c.decodeIfPresent(String.self, forKey: .value) ?? ""
        switch kind {
        case "zip": self = .zip(value)
        case "areaCode": self = .areaCode(value)
        case "manual": self = .manual
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "unknown kind \(kind)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .zip(let v):      try c.encode("zip", forKey: .kind);      try c.encode(v, forKey: .value)
        case .areaCode(let v): try c.encode("areaCode", forKey: .kind); try c.encode(v, forKey: .value)
        case .manual:          try c.encode("manual", forKey: .kind)
        }
    }
}

// MARK: - Card

struct BusinessCard: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: ContactField = ""
    var company: ContactField = ""
    var phones: [LabeledNumber] = []
    var email: ContactField = ""
    var address: ContactField = ""
    var timeZone: USTimeZone? = nil
    /// IANA identifier used to compute the local time; "" when unknown.
    var timeZoneId: String = ""
    var timeZoneSource: TimeZoneSource? = nil
    var scannedAt: Date = Date()
    
    var allFields: [ContactField] { [name, company] + phones.map(\.field) + [email, address] }
    var needsReview: Bool { allFields.contains { $0.needsReview } }
    var reviewCount: Int { allFields.filter(\.needsReview).count }
    
    /// "EST" etc., or "" when no zone was determined. Used by CSV export and the fixture evaluator.
    var timeZoneCode: String { timeZone?.rawValue ?? "" }
    
    mutating func markAllReviewed() {
        name.markReviewed()
        company.markReviewed()
        email.markReviewed()
        address.markReviewed()
        for i in phones.indices { phones[i].field.markReviewed() }
    }
}

extension BusinessCard {
    private enum CodingKeys: String, CodingKey {
        case id, name, company, phones, email, address, timeZone, timeZoneId, timeZoneSource, scannedAt
        // v1 keys, read only
        case timeZoneCode, timeZoneSourceAddress
    }
    
    /// Tolerant decoding: missing keys fall back to defaults, and v1 files
    /// (plain-string fields, timeZoneCode / timeZoneSourceAddress, no scannedAt) are mapped.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decodeIfPresent(UUID.self,            forKey: .id) ?? UUID()
        name     = try c.decodeIfPresent(ContactField.self,    forKey: .name) ?? ""
        company  = try c.decodeIfPresent(ContactField.self,    forKey: .company) ?? ""
        phones   = try c.decodeIfPresent([LabeledNumber].self, forKey: .phones) ?? []
        email    = try c.decodeIfPresent(ContactField.self,    forKey: .email) ?? ""
        address  = try c.decodeIfPresent(ContactField.self,    forKey: .address) ?? ""
        
        let legacyCode = try c.decodeIfPresent(String.self, forKey: .timeZoneCode) ?? ""
        timeZone = ((try? c.decodeIfPresent(USTimeZone.self, forKey: .timeZone)) ?? nil) ?? USTimeZone(rawValue: legacyCode)
        timeZoneId = try c.decodeIfPresent(String.self, forKey: .timeZoneId) ?? ""
        
        if let source = (try? c.decodeIfPresent(TimeZoneSource.self, forKey: .timeZoneSource)) ?? nil {
            timeZoneSource = source
        } else {
            let legacy = try c.decodeIfPresent(String.self, forKey: .timeZoneSourceAddress) ?? ""
            timeZoneSource = TimeZoneSource(legacySourceKey: legacy)
        }
        
        scannedAt = try c.decodeIfPresent(Date.self, forKey: .scannedAt) ?? .distantPast
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(company, forKey: .company)
        try c.encode(phones, forKey: .phones)
        try c.encode(email, forKey: .email)
        try c.encode(address, forKey: .address)
        try c.encodeIfPresent(timeZone, forKey: .timeZone)
        try c.encode(timeZoneId, forKey: .timeZoneId)
        try c.encodeIfPresent(timeZoneSource, forKey: .timeZoneSource)
        try c.encode(scannedAt, forKey: .scannedAt)
    }
}
