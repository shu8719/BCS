import SwiftUI

/// Small rounded chip with the US zone code, colored per zone.
struct TimeZoneChip: View {
    let zone: USTimeZone
    
    var body: some View {
        Text(zone.rawValue)
            .textStyle(.labelMedium)
            .foregroundStyle(M3.tzOnContainer(zone))
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .background(M3.tzContainer(zone))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
