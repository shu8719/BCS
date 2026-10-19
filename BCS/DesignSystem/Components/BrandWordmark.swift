import SwiftUI

/// App mark + "BCS" wordmark with the tagline, as in the Figma "Brand / Wordmark" component.
struct BrandWordmark: View {
    var body: some View {
        HStack(spacing: 10) {
            IconView(.brandMark, size: 36)
            VStack(alignment: .leading, spacing: 0) {
                (Text("BC") + Text("S").foregroundStyle(M3.primary))
                    .font(.system(size: 26, weight: .black))
                    .kerning(-1)
                    .foregroundStyle(M3.onSurface)
                    .frame(height: 28)
                Text("BUSINESS CARD SCANNER")
                    .font(.system(size: 9, weight: .medium))
                    .kerning(1.6)
                    .foregroundStyle(M3.onSurfaceVariant)
            }
        }
    }
}
