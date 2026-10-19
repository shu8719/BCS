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

/// Extended FAB with the camera icon, anchored by the caller at the bottom right.
struct ScanFAB: View {
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconView(.camera, size: 24, color: M3.onPrimaryContainer)
                Text(label)
                    .textStyle(.labelLarge)
                    .foregroundStyle(M3.onPrimaryContainer)
            }
            .padding(.leading, 16)
            .padding(.trailing, 20)
            .padding(.vertical, 16)
            .background(M3.primaryContainer)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 4)
            .shadow(color: .black.opacity(0.3), radius: 1.5, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}
