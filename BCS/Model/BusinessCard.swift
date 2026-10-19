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

// Tolerant decoding: fields added in later versions fall back to their defaults
// instead of failing the whole decode (which would otherwise drop every stored card).
// Declared in extensions so the synthesized memberwise / default initializers are kept.
extension BusinessCard {
    private enum CodingKeys: String, CodingKey {
        case id, name, company, phones, email, address, timeZoneCode, timeZoneId, timeZoneSourceAddress
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                    = try c.decodeIfPresent(UUID.self,            forKey: .id) ?? UUID()
        name                  = try c.decodeIfPresent(String.self,          forKey: .name) ?? ""
        company               = try c.decodeIfPresent(String.self,          forKey: .company) ?? ""
        phones                = try c.decodeIfPresent([LabeledNumber].self, forKey: .phones) ?? []
        email                 = try c.decodeIfPresent(String.self,          forKey: .email) ?? ""
        address               = try c.decodeIfPresent(String.self,          forKey: .address) ?? ""
        timeZoneCode          = try c.decodeIfPresent(String.self,          forKey: .timeZoneCode) ?? ""
        timeZoneId            = try c.decodeIfPresent(String.self,          forKey: .timeZoneId) ?? ""
        timeZoneSourceAddress = try c.decodeIfPresent(String.self,          forKey: .timeZoneSourceAddress) ?? ""
    }
}

extension LabeledNumber {
    private enum CodingKeys: String, CodingKey {
        case id, label, number
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id     = try c.decodeIfPresent(UUID.self,       forKey: .id) ?? UUID()
        label  = try c.decodeIfPresent(PhoneLabel.self, forKey: .label) ?? .unknown
        number = try c.decodeIfPresent(String.self,     forKey: .number) ?? ""
    }
}
