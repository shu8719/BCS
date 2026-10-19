import SwiftUI

/// Avatar background tone. Rotation order follows the design (primary → tertiary → secondary).
enum AvatarTone: CaseIterable {
    case primary, secondary, tertiary
    
    /// Stable across launches: derived from the name's Unicode scalars, never from `Hasher`
    /// (which is seeded per process), so a card keeps its color however the list is sorted.
    static func tone(for name: String) -> AvatarTone {
        let sum = name.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 3 }
        return [.primary, .tertiary, .secondary][sum]
    }
    
    var container: Color {
        switch self {
        case .primary:   return M3.primaryContainer
        case .secondary: return M3.secondaryContainer
        case .tertiary:  return M3.tertiaryContainer
        }
    }
    
    var onContainer: Color {
        switch self {
        case .primary:   return M3.onPrimaryContainer
        case .secondary: return M3.onSecondaryContainer
        case .tertiary:  return M3.onTertiaryContainer
        }
    }
}

/// Circle with the person's initials; optional warning dot at the top right.
struct InitialsAvatar: View {
    let name: String
    var size: CGFloat = 32
    var showsReviewBadge: Bool = false
    
    /// "DAVID MORGAN" → "RD", "Northwind" → "AS", "" → "?"
    static func initials(of name: String) -> String {
        let words = name.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard let first = words.first else { return "?" }
        if words.count >= 2, let a = first.first, let b = words[1].first {
            return String([a, b]).uppercased()
        }
        return String(first.prefix(2)).uppercased()
    }
    
    var body: some View {
        let tone = AvatarTone.tone(for: name)
        let large = size >= 56
        ZStack {
            Circle().fill(tone.container)
            Text(Self.initials(of: name))
                .font(.system(size: large ? 28 : 14, weight: large ? .bold : .medium))
                .foregroundStyle(tone.onContainer)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            if showsReviewBadge {
                IconView(.reviewBadge, size: large ? 18 : 12)
                    .offset(x: large ? 0 : 2, y: large ? 2 : -2)
            }
        }
    }
}

#if DEBUG && canImport(UIKit)
#Preview {
    HStack(spacing: 16) {
        InitialsAvatar(name: "DAVID MORGAN")
        InitialsAvatar(name: "Mark Ellis", showsReviewBadge: true)
        InitialsAvatar(name: "Linda Chen", size: 72, showsReviewBadge: true)
    }
    .padding()
}
#endif
