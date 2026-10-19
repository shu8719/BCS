import SwiftUI

/// Amber banner used for "要確認" notices, with an optional white pill action.
struct ReviewBanner: View {
    let title: String
    var subtitle: String? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil
    
    private var foreground: Color { M3.tzOnContainer(.mst) }
    
    var body: some View {
        HStack(alignment: subtitle == nil && actionLabel == nil ? .top : .center, spacing: 12) {
            IconView(.warning, size: 20, color: foreground)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .textStyle(subtitle == nil ? .bodyMedium : .labelLarge)
                    .foregroundStyle(foreground)
                if let subtitle {
                    Text(subtitle)
                        .textStyle(.bodySmall)
                        .foregroundStyle(foreground.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let actionLabel, let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        IconView(.check, size: 16, color: foreground)
                        Text(actionLabel)
                            .textStyle(.labelMedium)
                            .foregroundStyle(foreground)
                    }
                    .padding(.leading, 10)
                    .padding(.trailing, 12)
                    .padding(.vertical, 8)
                    .background(M3.surfaceContainerLowest)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, actionLabel == nil ? 16 : 8)
        .padding(.vertical, 10)
        .background(M3.tzContainer(.mst))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
