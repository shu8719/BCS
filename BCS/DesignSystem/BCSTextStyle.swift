import SwiftUI

/// Typography scale from the Figma design (Noto Sans JP sizes, rendered with the system font).
enum BCSTextStyle {
    case headlineMedium, headlineSmall
    case titleLarge, titleMedium, titleSmall
    case bodyLarge, bodyMedium, bodySmall
    case labelLarge, labelMedium, labelSmall
    
    var size: CGFloat {
        switch self {
        case .headlineMedium: return 28
        case .headlineSmall:  return 24
        case .titleLarge:     return 22
        case .titleMedium:    return 16
        case .titleSmall:     return 14
        case .bodyLarge:      return 16
        case .bodyMedium:     return 14
        case .bodySmall:      return 12
        case .labelLarge:     return 14
        case .labelMedium:    return 12
        case .labelSmall:     return 11
        }
    }
    
    var lineHeight: CGFloat {
        switch self {
        case .headlineMedium: return 36
        case .headlineSmall:  return 32
        case .titleLarge:     return 28
        case .titleMedium:    return 24
        case .titleSmall:     return 20
        case .bodyLarge:      return 24
        case .bodyMedium:     return 20
        case .bodySmall:      return 16
        case .labelLarge:     return 20
        case .labelMedium:    return 16
        case .labelSmall:     return 16
        }
    }
    
    var weight: Font.Weight {
        switch self {
        case .headlineMedium, .headlineSmall: return .bold
        case .bodyLarge, .bodyMedium, .bodySmall: return .regular
        default: return .medium
        }
    }
    
    var font: Font { .system(size: size, weight: weight) }
}

extension View {
    /// Applies the style's font and approximates its line height with extra line spacing.
    func textStyle(_ style: BCSTextStyle) -> some View {
        self
            .font(style.font)
            .lineSpacing(max(0, style.lineHeight - style.size * 1.2))
    }
}
