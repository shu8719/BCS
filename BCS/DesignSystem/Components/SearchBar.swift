import SwiftUI

/// Material 3 search bar look (56pt, fully rounded) over a plain TextField.
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack(spacing: 12) {
            IconView(.search, size: 24, color: M3.onSurfaceVariant)
            TextField(placeholder, text: $text)
                .textStyle(.bodyLarge)
                .foregroundStyle(M3.onSurface)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    IconView(.close, size: 20, color: M3.onSurfaceVariant)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(M3.surfaceContainerHigh)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}
