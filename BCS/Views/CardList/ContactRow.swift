import SwiftUI

/// One card in the list (List Item / Contact): avatar or check circle, name + company,
/// time zone chip with the current local time on the right.
struct ContactRow: View {
    @EnvironmentObject private var settings: AppSettings
    let card: BusinessCard
    var isSelecting: Bool = false
    var isSelected: Bool = false
    let now: Date
    
    var body: some View {
        HStack(spacing: 12) {
            if isSelecting && isSelected {
                ZStack {
                    Circle().fill(M3.primary)
                    IconView(.check, size: 18, color: M3.onPrimary)
                }
                .frame(width: 32, height: 32)
            } else {
                InitialsAvatar(name: card.name.value, showsReviewBadge: card.needsReview)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .textStyle(.titleMedium)
                    .foregroundStyle(M3.onSurface)
                    .lineLimit(1)
                if !card.company.isEmpty {
                    Text(card.company.value)
                        .textStyle(.bodySmall)
                        .foregroundStyle(M3.onSurfaceVariant)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if let zone = card.timeZone {
                VStack(alignment: .trailing, spacing: 4) {
                    TimeZoneChip(zone: zone)
                    let identifier = card.timeZoneId.isEmpty ? zone.representativeIdentifier : card.timeZoneId
                    if let time = LocalTime.hourMinute(in: identifier, at: now) {
                        Text(L10n.t(.localTime, lang: settings.language, time))
                            .textStyle(.labelSmall)
                            .foregroundStyle(M3.onSurfaceVariant)
                    }
                }
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 60)
        .background(isSelected ? M3.secondaryContainer : M3.surfaceContainerLowest)
        .contentShape(Rectangle())
    }
    
    private var title: String {
        if !card.name.isEmpty { return card.name.value }
        if !card.company.isEmpty { return card.company.value }
        if !card.email.isEmpty { return card.email.value }
        return "—"
    }
}
