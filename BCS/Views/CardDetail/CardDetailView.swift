import SwiftUI

/// 03 名刺詳細: hero, review banner, quick actions, contact fields, scan metadata.
struct CardDetailView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(CardStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    let cardID: UUID
    
    @State private var editDraft: BusinessCard?
    @State private var confirmDelete = false
    
    private var lang: AppSettings.Language { settings.language }
    
    var body: some View {
        ZStack {
            M3.surfaceContainerLow.ignoresSafeArea()
            if let card = store.card(id: cardID) {
                VStack(spacing: 0) {
                    topBar
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            hero(card)
                            if card.reviewCount > 0 { reviewBanner(card) }
                            quickActions(card)
                            SectionHeader(L10n.t(.contactInfo, lang: lang))
                            fields(card)
                            meta(card)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editDraft) { draft in
            CardEditView(card: draft,
                         onSave: { store.update($0) },
                         onDelete: { store.delete(id: cardID); dismiss() })
        }
        .confirmationDialog(L10n.t(.deleteThisCard, lang: lang), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L10n.t(.deleteAction, lang: lang), role: .destructive) {
                store.delete(id: cardID)
                dismiss()
            }
            Button(L10n.t(.cancel, lang: lang), role: .cancel) {}
        }
        .onChange(of: store.card(id: cardID) == nil) { _, gone in
            if gone { dismiss() }
        }
    }
    
    // MARK: - Sections
    
    private var topBar: some View {
        HStack(spacing: 0) {
            IconButton(.arrowBack) { dismiss() }
            Spacer()
            IconButton(.edit) { editDraft = store.card(id: cardID) }
            Menu {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label(L10n.t(.deleteThisCard, lang: lang), systemImage: "trash")
                }
            } label: {
                IconView(.moreVert, size: 24, color: M3.onSurface)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }
    
    private func hero(_ card: BusinessCard) -> some View {
        VStack(spacing: 4) {
            InitialsAvatar(name: card.name.value, size: 72, showsReviewBadge: card.needsReview)
                .padding(.bottom, 8)
            Text(card.name.isEmpty ? "—" : card.name.value)
                .textStyle(.headlineSmall)
                .foregroundStyle(M3.onSurface)
                .multilineTextAlignment(.center)
            if !card.company.isEmpty {
                Text(card.company.value)
                    .textStyle(.bodyLarge)
                    .foregroundStyle(M3.onSurfaceVariant)
            }
            if let zone = card.timeZone {
                TimelineView(.everyMinute) { context in
                    HStack(spacing: 8) {
                        TimeZoneChip(zone: zone)
                        if let line = CardDetailText.timeZoneLine(card: card, now: context.date, lang: lang) {
                            Text(line)
                                .textStyle(.bodyMedium)
                                .foregroundStyle(M3.onSurfaceVariant)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }
    
    private func reviewBanner(_ card: BusinessCard) -> some View {
        ReviewBanner(
            title: L10n.t(.reviewItemsTitle, lang: lang, card.reviewCount),
            subtitle: CardDetailText.reviewBannerSubtitle(card: card, lang: lang),
            actionLabel: L10n.t(.markReviewed, lang: lang),
            action: { store.markAllReviewed(id: cardID) }
        )
    }
    
    private func quickActions(_ card: BusinessCard) -> some View {
        let phone = card.phones.first?.number.filter { $0.isNumber || $0 == "+" } ?? ""
        let email = card.email.value
        let address = card.address.value
        return HStack(spacing: 8) {
            QuickActionButton(icon: .call, label: L10n.t(.actionCall, lang: lang), enabled: !phone.isEmpty) {
                open("tel:\(phone)")
            }
            QuickActionButton(icon: .mail, label: L10n.t(.actionMail, lang: lang), enabled: !email.isEmpty) {
                open("mailto:\(email)")
            }
            QuickActionButton(icon: .location, label: L10n.t(.actionMap, lang: lang), enabled: !address.isEmpty) {
                let query = address.replacingOccurrences(of: " / ", with: ", ")
                    .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                open("http://maps.apple.com/?q=\(query)")
            }
        }
    }
    
    private func fields(_ card: BusinessCard) -> some View {
        GroupedRows(cornerRadius: 20) {
            if card.name.needsReview {
                fieldRow(icon: .person, label: L10n.t(.name, lang: lang), field: card.name)
            }
            if card.company.needsReview {
                fieldRow(icon: .business, label: L10n.t(.company, lang: lang), field: card.company)
            }
            ForEach(card.phones) { phone in
                fieldRow(icon: .call, label: CardDetailText.phoneLabel(phone.label, lang: lang), field: phone.field)
            }
            if !card.email.isEmpty || card.email.needsReview {
                fieldRow(icon: .mail, label: L10n.t(.email, lang: lang), field: card.email)
            }
            if !card.address.isEmpty || card.address.needsReview {
                fieldRow(icon: .location, label: L10n.t(.address, lang: lang), field: card.address,
                         display: card.address.value.replacingOccurrences(of: " / ", with: "\n"))
            }
        }
    }
    
    @ViewBuilder
    private func fieldRow(icon: BCSIcon, label: String, field: ContactField, display: String? = nil) -> some View {
        let flagged = field.needsReview
        FieldRow(
            icon: icon,
            label: flagged ? label + L10n.t(.reviewSuffix, lang: lang) : label,
            value: display ?? field.value,
            trailing: flagged ? .edit : .copy,
            highlighted: flagged,
            labelColor: flagged ? M3.warning : M3.onSurfaceVariant,
            onTrailing: {
                if flagged {
                    editDraft = store.card(id: cardID)
                } else {
                    UIPasteboard.general.string = field.value
                }
            }
        )
        if flagged, let note = CardDetailText.reviewNote(field: field, lang: lang) {
            ReviewNoteRow(text: note)
        }
    }
    
    private func meta(_ card: BusinessCard) -> some View {
        HStack(alignment: .top, spacing: 8) {
            IconView(.info, size: 16, color: M3.onSurfaceVariant)
            Text(CardDetailText.metaLine(card: card, lang: lang))
                .textStyle(.bodySmall)
                .foregroundStyle(M3.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }
    
    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        openURL(url)
    }
}
