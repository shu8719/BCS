import SwiftUI

/// The detail card at the top of the list showing the selected card's fields.
struct CardSummaryView: View {
    @EnvironmentObject private var settings: AppSettings
    let card: BusinessCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            infoRow(L10n.t(.name,    lang: settings.language), card.name,           iconAsset: "IconPerson")
            infoRow(L10n.t(.company, lang: settings.language), card.company,        iconAsset: "IconBuilding")
            infoRow(L10n.t(.phone,   lang: settings.language), displayPhones,       iconAsset: "IconPhone")
            infoRow(L10n.t(.email,   lang: settings.language), card.email,          iconAsset: "IconEmail")
            infoRow(L10n.t(.address, lang: settings.language), card.address,        iconAsset: "IconMap", badgeCode: card.timeZoneCode)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.75))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.6), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 8)
        )
    }
    
    private var displayPhones: String {
        card.phones.map(\.number).joined(separator: " / ")
    }
    
    private func infoRow(_ title: String, _ value: String, iconAsset: String, badgeCode: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(iconAsset)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                Text(title)
                    .font(.custom("AvenirNext-Medium", size: 11))
                    .foregroundStyle(.secondary)
            }
            if let badgeCode, !badgeCode.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    valueText(value)
                        .layoutPriority(1)
                    Spacer(minLength: 4)
                    TimeZoneBadgeView(code: badgeCode)
                }
            } else {
                valueText(value)
            }
        }
    }
    
    private func valueText(_ value: String) -> some View {
        Text(value.isEmpty ? "Unknown" : value)
            .font(.custom("AvenirNext-Regular", size: 16))
            .foregroundStyle(.primary)
    }
}
