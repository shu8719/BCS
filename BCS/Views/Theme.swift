import SwiftUI

/// Colors shared by the card screens.
enum Theme {
    static let bgTop      = Color(red: 0.95, green: 0.97, blue: 1.00)
    static let bgBottom   = Color(red: 0.98, green: 0.95, blue: 0.96)
    static let accent     = Color(red: 0.16, green: 0.46, blue: 0.86)
    static let accentSoft = Color(red: 0.84, green: 0.90, blue: 1.00)
    
    static func timeZoneColor(for code: String) -> Color {
        switch code {
        case "PST": return .red
        case "MST": return .blue
        case "CST": return .green
        case "EST": return Color(red: 0.95, green: 0.78, blue: 0.15)
        default:    return .gray
        }
    }
}

struct PillButtonStyle: ButtonStyle {
    let background: Color
    let foreground: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("AvenirNext-DemiBold", size: 14))
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(background.opacity(configuration.isPressed ? 0.85 : 1.0))
            .foregroundStyle(foreground)
            .clipShape(Capsule())
    }
}
