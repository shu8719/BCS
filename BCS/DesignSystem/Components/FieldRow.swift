import SwiftUI

enum FieldRowTrailing {
    case none, copy, edit
}

/// One contact field (List Item / Field): icon, small label, value, optional trailing action.
struct FieldRow: View {
    let icon: BCSIcon
    let label: String
    let value: String
    var trailing: FieldRowTrailing = .none
    var highlighted: Bool = false
    var labelColor: Color = M3.onSurfaceVariant
    /// E-mail addresses and phone numbers read better shrunk onto one line than wrapped mid-word.
    var singleLine: Bool = false
    var onTrailing: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            IconView(icon, size: 24, color: M3.onSurfaceVariant)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .textStyle(.labelMedium)
                    .foregroundStyle(labelColor)
                Text(value)
                    .textStyle(.bodyLarge)
                    .foregroundStyle(M3.onSurface)
                    .lineLimit(singleLine ? 1 : nil)
                    .minimumScaleFactor(singleLine ? 0.8 : 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if trailing != .none, let onTrailing {
                Button(action: onTrailing) {
                    IconView(trailing == .copy ? .copy : .edit, size: 20, color: M3.onSurfaceVariant)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
        .frame(minHeight: 72)
        .background(highlighted ? M3.surfaceContainerHighest : M3.surfaceContainerLowest)
    }
}

/// Indented warning line shown directly under a highlighted FieldRow.
struct ReviewNoteRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            IconView(.warning, size: 14, color: M3.warning)
            Text(text)
                .textStyle(.bodySmall)
                .foregroundStyle(M3.warning)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 56)
        .padding(.trailing, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(M3.surfaceContainerHighest)
    }
}

/// Rows separated by 2pt of the page background, clipped to a rounded group.
struct GroupedRows<Content: View>: View {
    var cornerRadius: CGFloat = 16
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(spacing: 2) { content() }
            .background(M3.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
