import SwiftUI

enum BCSButtonStyle {
    case filled, tonal, outlined, text, danger
}

/// Material 3 button: 40pt tall, fully rounded, optional 18pt leading icon.
struct BCSButton: View {
    let label: String
    var icon: BCSIcon? = nil
    var style: BCSButtonStyle = .filled
    var fullWidth: Bool = false
    let action: () -> Void
    
    init(_ label: String, icon: BCSIcon? = nil, style: BCSButtonStyle = .filled, fullWidth: Bool = false,
         action: @escaping () -> Void) {
        self.label = label
        self.icon = icon
        self.style = style
        self.fullWidth = fullWidth
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    IconView(icon, size: 18, color: foreground)
                }
                Text(label)
                    .textStyle(.labelLarge)
                    .foregroundStyle(foreground)
                    .lineLimit(1)
            }
            .padding(.leading, icon == nil ? (style == .text ? 12 : 24) : 16)
            .padding(.trailing, style == .text ? 12 : 24)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: 40)
            .background(background)
            .overlay {
                if style == .outlined {
                    Capsule().stroke(M3.outlineVariant, lineWidth: 1)
                }
            }
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var background: Color {
        switch style {
        case .filled:   return M3.primary
        case .tonal:    return M3.secondaryContainer
        case .danger:   return M3.errorContainer
        case .outlined, .text: return .clear
        }
    }
    
    private var foreground: Color {
        switch style {
        case .filled:   return M3.onPrimary
        case .tonal:    return M3.onSecondaryContainer
        case .danger:   return M3.onErrorContainer
        case .outlined, .text: return M3.primary
        }
    }
}

/// 48×48 tap target around a 24pt icon.
struct IconButton: View {
    let icon: BCSIcon
    var color: Color = M3.onSurface
    let action: () -> Void
    
    init(_ icon: BCSIcon, color: Color = M3.onSurface, action: @escaping () -> Void) {
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            IconView(icon, size: 24, color: color)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG && canImport(UIKit)
#Preview {
    VStack(spacing: 12) {
        BCSButton("保存", style: .filled) {}
        BCSButton("CSVで書き出す", icon: .download, style: .tonal) {}
        BCSButton("撮り直す", icon: .camera, style: .outlined) {}
        BCSButton("電話を追加", icon: .add, style: .text) {}
        BCSButton("削除", icon: .delete, style: .danger, fullWidth: true) {}
        IconButton(.sort) {}
    }
    .padding()
}
#endif
