import SwiftUI

/// Tonal tile with an icon over a label (電話 / メール / 地図).
struct QuickActionButton: View {
    let icon: BCSIcon
    let label: String
    var enabled: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                IconView(icon, size: 24, color: M3.onSecondaryContainer)
                Text(label)
                    .textStyle(.labelLarge)
                    .foregroundStyle(M3.onSecondaryContainer)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(M3.secondaryContainer)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .opacity(enabled ? 1 : 0.38)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
