import SwiftUI

/// One entry in the card list.
struct CardRowView: View {
    let card: BusinessCard
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("AvenirNext-DemiBold", size: 16))
                    .foregroundStyle(.primary)
                if !card.company.isEmpty {
                    Text(card.company.value)
                        .font(.custom("AvenirNext-Regular", size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Theme.accentSoft.opacity(0.8) : Color.white.opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Theme.accent.opacity(0.4) : Color.white.opacity(0.6), lineWidth: 1))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 4)
    }
    
    private var title: String {
        if !card.name.isEmpty    { return card.name.value }
        if !card.company.isEmpty { return card.company.value }
        if !card.email.isEmpty   { return card.email.value }
        return "Unknown"
    }
}
