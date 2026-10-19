import SwiftUI

/// Small colored capsule showing PST / MST / CST / EST.
struct TimeZoneBadgeView: View {
    let code: String
    
    var body: some View {
        let color = Theme.timeZoneColor(for: code)
        Text(code)
            .font(.custom("AvenirNext-DemiBold", size: 12))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
