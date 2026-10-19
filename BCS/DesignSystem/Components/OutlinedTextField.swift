import SwiftUI

/// Material 3 outlined text field: 1pt outline, 8pt corners, label floating on the border.
struct OutlinedTextField: View {
    let label: String
    @Binding var text: String
    var multiline: Bool = false
    var keyboard: UIKeyboardType = .default
    var trailing: BCSIcon? = nil
    var onTrailing: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("", text: $text, axis: multiline ? .vertical : .horizontal)
                .textStyle(.bodyLarge)
                .foregroundStyle(M3.onSurface)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .lineLimit(multiline ? 1...6 : 1...1)
            if let trailing, let onTrailing {
                Button(action: onTrailing) {
                    IconView(trailing, size: 24, color: M3.onSurfaceVariant)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 16)
        .overlay {
            RoundedRectangle(cornerRadius: 8).stroke(M3.outline, lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            Text(label)
                .textStyle(.bodySmall)
                .foregroundStyle(M3.onSurfaceVariant)
                .padding(.horizontal, 4)
                .background(M3.surface)
                .offset(x: 11, y: -9)
        }
    }
}

/// Equal-width segments inside one outlined pill; the selected one is tonal with a check.
struct SegmentedButton<T: Hashable>: View {
    let options: [(value: T, label: String)]
    @Binding var selection: T
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let selected = option.value == selection
                Button { selection = option.value } label: {
                    HStack(spacing: 6) {
                        if selected {
                            IconView(.check, size: 18, color: M3.onSecondaryContainer)
                        }
                        Text(option.label)
                            .textStyle(.labelLarge)
                            .foregroundStyle(selected ? M3.onSecondaryContainer : M3.onSurface)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(selected ? M3.secondaryContainer : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < options.count - 1 {
                    Rectangle().fill(M3.outline).frame(width: 1)
                }
            }
        }
        .overlay {
            Capsule().stroke(M3.outline, lineWidth: 1)
        }
        .clipShape(Capsule())
    }
}
