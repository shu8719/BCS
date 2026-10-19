import SwiftUI

enum FilterChipTint {
    case secondary, warning
}

/// 32pt filter chip. Selected chips are filled; unselected ones are outlined.
struct FilterChip: View {
    let label: String
    var leading: BCSIcon? = nil
    var trailing: BCSIcon? = nil
    var selected: Bool = false
    var tint: FilterChipTint = .secondary
    let action: () -> Void
    
    init(_ label: String, leading: BCSIcon? = nil, trailing: BCSIcon? = nil, selected: Bool = false,
         tint: FilterChipTint = .secondary, action: @escaping () -> Void) {
        self.label = label
        self.leading = leading
        self.trailing = trailing
        self.selected = selected
        self.tint = tint
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let leading {
                    IconView(leading, size: 18, color: foreground)
                }
                Text(label)
                    .textStyle(.labelLarge)
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                if let trailing {
                    IconView(trailing, size: 18, color: foreground)
                }
            }
            .padding(.leading, leading == nil ? 12 : 8)
            .padding(.trailing, trailing == nil ? 12 : 6)
            .frame(height: 32)
            .background(selected ? fill : Color.clear)
            .overlay {
                if !selected {
                    RoundedRectangle(cornerRadius: 8).stroke(M3.outlineVariant, lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    private var fill: Color {
        tint == .warning ? M3.tzContainer(.mst) : M3.secondaryContainer
    }
    
    private var foreground: Color {
        guard selected else { return M3.onSurfaceVariant }
        return tint == .warning ? M3.tzOnContainer(.mst) : M3.onSecondaryContainer
    }
}
