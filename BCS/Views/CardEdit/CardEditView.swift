import SwiftUI

/// 04 編集: modal sheet with outlined fields. Saving clears the review flag of every changed field.
struct CardEditView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    private let original: BusinessCard
    private let onSave: (BusinessCard) -> Void
    private let onDelete: (() -> Void)?
    
    @State private var draft: BusinessCard
    @State private var confirmDelete = false
    
    init(card: BusinessCard, onSave: @escaping (BusinessCard) -> Void, onDelete: (() -> Void)? = nil) {
        self.original = card
        self.onSave = onSave
        self.onDelete = onDelete
        _draft = State(initialValue: card)
    }
    
    private var lang: AppSettings.Language { settings.language }
    
    var body: some View {
        Group {
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        OutlinedTextField(label: L10n.t(.name, lang: lang), text: $draft.name.value)
                        OutlinedTextField(label: L10n.t(.company, lang: lang), text: $draft.company.value)
                        phones
                        OutlinedTextField(label: L10n.t(.email, lang: lang), text: $draft.email.value, keyboard: .emailAddress)
                            .textInputAutocapitalization(.never)
                        OutlinedTextField(label: L10n.t(.address, lang: lang), text: $draft.address.value, multiline: true)
                        timeZoneCard
                        if onDelete != nil { deleteButton }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(M3.surface.ignoresSafeArea())
        .confirmationDialog(L10n.t(.deleteThisCard, lang: lang), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L10n.t(.deleteAction, lang: lang), role: .destructive) {
                dismiss()
                onDelete?()
            }
            Button(L10n.t(.cancel, lang: lang), role: .cancel) {}
        }
    }
    
    private var topBar: some View {
        HStack(spacing: 4) {
            IconButton(.close) { dismiss() }
            Text(L10n.t(.editCardTitle, lang: lang))
                .textStyle(.titleLarge)
                .foregroundStyle(M3.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
            BCSButton(L10n.t(.save, lang: lang), style: .filled) {
                onSave(CardEditLogic.applyingEdits(original: original, draft: draft))
                dismiss()
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
    }
    
    private var phones: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(draft.phones.enumerated()), id: \.element.id) { index, phone in
                OutlinedTextField(
                    label: phoneFieldLabel(phone, index: index),
                    text: numberBinding(for: phone.id),
                    keyboard: .phonePad,
                    trailing: .removeCircle,
                    onTrailing: { draft.phones.removeAll { $0.id == phone.id } }
                )
            }
            BCSButton(L10n.t(.addPhone, lang: lang), icon: .add, style: .text) {
                draft.phones.append(LabeledNumber(label: .unknown, number: ""))
            }
        }
    }
    
    private func numberBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { draft.phones.first { $0.id == id }?.number ?? "" },
            set: { newValue in
                if let i = draft.phones.firstIndex(where: { $0.id == id }) { draft.phones[i].number = newValue }
            }
        )
    }
    
    private func phoneFieldLabel(_ phone: LabeledNumber, index: Int) -> String {
        if phone.label == .unknown {
            return L10n.t(.phoneN, lang: lang, index + 1)
        }
        return L10n.t(.phoneWithLabel, lang: lang, CardDetailText.phoneLabel(phone.label, lang: lang))
    }
    
    private var timeZoneCard: some View {
        HStack(spacing: 16) {
            IconView(.schedule, size: 24, color: M3.onSurfaceVariant)
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.t(.tzAuto, lang: lang))
                    .textStyle(.labelMedium)
                    .foregroundStyle(M3.onSurfaceVariant)
                Text(zoneName)
                    .textStyle(.bodyLarge)
                    .foregroundStyle(M3.onSurface)
                if let basis {
                    Text(basis)
                        .textStyle(.bodySmall)
                        .foregroundStyle(M3.onSurfaceVariant)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let zone = draft.timeZone {
                TimeZoneChip(zone: zone)
            }
        }
        .padding(16)
        .background(M3.surfaceContainerHigh)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var zoneName: String {
        switch draft.timeZone {
        case .est: return L10n.t(.tzNameEST, lang: lang)
        case .cst: return L10n.t(.tzNameCST, lang: lang)
        case .mst: return L10n.t(.tzNameMST, lang: lang)
        case .pst: return L10n.t(.tzNamePST, lang: lang)
        case nil:  return L10n.t(.tzUnknown, lang: lang)
        }
    }
    
    private var basis: String? {
        switch draft.timeZoneSource {
        case .zip(let zip):       return L10n.t(.tzBasisZip, lang: lang, zip)
        case .areaCode(let area): return L10n.t(.tzBasisAreaCode, lang: lang, area)
        case .manual:             return L10n.t(.tzManual, lang: lang)
        case nil:                 return nil
        }
    }
    
    private var deleteButton: some View {
        Button { confirmDelete = true } label: {
            HStack(spacing: 8) {
                IconView(.delete, size: 18, color: M3.error)
                Text(L10n.t(.deleteThisCard, lang: lang))
                    .textStyle(.labelLarge)
                    .foregroundStyle(M3.error)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
        }
        .buttonStyle(.plain)
    }
}
