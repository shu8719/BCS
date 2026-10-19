import SwiftUI

/// 06 読み取り結果: review the parsed card, fix single fields, then save or retake.
/// The card is only persisted when the user taps 保存する.
struct ScanResultView: View {
    @EnvironmentObject private var settings: AppSettings
    
    let card: BusinessCard
    let onChange: (BusinessCard) -> Void
    let onSave: () -> Void
    let onRetake: () -> Void
    let onCancel: () -> Void
    
    private enum Target: Identifiable {
        case name, company, phone(UUID), email, address
        var id: String {
            switch self {
            case .name: return "name"
            case .company: return "company"
            case .phone(let id): return "phone-\(id.uuidString)"
            case .email: return "email"
            case .address: return "address"
            }
        }
    }
    
    @State private var editing: Target?
    
    private var lang: AppSettings.Language { settings.language }
    
    var body: some View {
        ZStack {
            M3.surfaceContainerLow.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let banner = bannerText {
                            ReviewBanner(title: banner)
                        }
                        SectionHeader(L10n.t(.readFieldsCount, lang: lang, readCount),
                                      trailing: L10n.t(.tapToFix, lang: lang))
                        fields
                        timeZoneLine
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
                bottomBar
            }
        }
        .sheet(item: $editing) { target in
            FieldEditSheet(title: title(for: target), value: value(for: target),
                           multiline: isAddress(target), keyboard: keyboard(for: target)) { newValue in
                apply(newValue, to: target)
            }
        }
    }
    
    // MARK: - Sections
    
    private var topBar: some View {
        HStack(spacing: 4) {
            IconButton(.close) { onCancel() }
            Text(L10n.t(.scanResultTitle, lang: lang))
                .textStyle(.titleLarge)
                .foregroundStyle(M3.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                Button(role: .destructive) { onCancel() } label: {
                    Label(L10n.t(.cancel, lang: lang), systemImage: "xmark")
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
    
    private var bannerText: String? {
        if let phone = card.phones.first(where: { $0.field.reviewReason == .malformed }) {
            return L10n.t(.bannerMalformedPhone, lang: lang, phone.number)
        }
        if let phone = card.phones.first(where: { $0.field.reviewReason == .normalized }) {
            return L10n.t(.bannerNormalizedPhone, lang: lang, phone.field.rawValue ?? "")
        }
        if card.company.reviewReason == .inferred {
            return L10n.t(.bannerInferredCompany, lang: lang)
        }
        if card.name.reviewReason == .missing || card.company.reviewReason == .missing {
            return L10n.t(.bannerMissing, lang: lang)
        }
        return nil
    }
    
    private var readCount: Int {
        [card.name, card.company, card.email, card.address].filter { !$0.isEmpty }.count
            + card.phones.filter { !$0.field.isEmpty }.count
    }
    
    private var fields: some View {
        GroupedRows(cornerRadius: 20) {
            row(.name, icon: .person, label: L10n.t(.name, lang: lang), field: card.name)
            row(.company, icon: .business, label: L10n.t(.company, lang: lang), field: card.company)
            ForEach(card.phones) { phone in
                row(.phone(phone.id), icon: .call,
                    label: L10n.t(.phoneWithLabel, lang: lang, CardDetailText.phoneLabel(phone.label, lang: lang)),
                    field: phone.field)
            }
            row(.email, icon: .mail, label: L10n.t(.email, lang: lang), field: card.email, singleLine: true)
            row(.address, icon: .location, label: L10n.t(.address, lang: lang), field: card.address,
                display: card.address.value.replacingOccurrences(of: " / ", with: ", "))
        }
    }
    
    private func row(_ target: Target, icon: BCSIcon, label: String, field: ContactField,
                     display: String? = nil, singleLine: Bool = false) -> some View {
        let flagged = field.needsReview
        return FieldRow(
            icon: icon,
            label: flagged ? label + L10n.t(.reviewSuffix, lang: lang) : label,
            value: display ?? (field.isEmpty ? "—" : field.value),
            trailing: .edit,
            highlighted: flagged,
            singleLine: singleLine,
            onTrailing: { editing = target }
        )
        .contentShape(Rectangle())
        .onTapGesture { editing = target }
    }
    
    @ViewBuilder
    private var timeZoneLine: some View {
        if let zone = card.timeZone {
            HStack(spacing: 8) {
                TimeZoneChip(zone: zone)
                if let text = sourceText {
                    Text(text)
                        .textStyle(.bodySmall)
                        .foregroundStyle(M3.onSurfaceVariant)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var sourceText: String? {
        switch card.timeZoneSource {
        case .zip(let zip):       return L10n.t(.tzFromZipShort, lang: lang, zip)
        case .areaCode(let area): return L10n.t(.tzFromAreaCodeShort, lang: lang, area)
        case .manual:             return L10n.t(.tzManual, lang: lang)
        case nil:                 return nil
        }
    }
    
    private var bottomBar: some View {
        HStack(spacing: 12) {
            BCSButton(L10n.t(.retake, lang: lang), icon: .camera, style: .outlined, fullWidth: true) { onRetake() }
            BCSButton(L10n.t(.saveCard, lang: lang), icon: .check, style: .filled, fullWidth: true) { onSave() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(M3.surfaceContainer.ignoresSafeArea())
    }
    
    // MARK: - Single-field editing
    
    private func title(for target: Target) -> String {
        switch target {
        case .name: return L10n.t(.name, lang: lang)
        case .company: return L10n.t(.company, lang: lang)
        case .phone(let id):
            let label = card.phones.first { $0.id == id }?.label ?? .unknown
            return L10n.t(.phoneWithLabel, lang: lang, CardDetailText.phoneLabel(label, lang: lang))
        case .email: return L10n.t(.email, lang: lang)
        case .address: return L10n.t(.address, lang: lang)
        }
    }
    
    private func value(for target: Target) -> String {
        switch target {
        case .name: return card.name.value
        case .company: return card.company.value
        case .phone(let id): return card.phones.first { $0.id == id }?.number ?? ""
        case .email: return card.email.value
        case .address: return card.address.value
        }
    }
    
    private func isAddress(_ target: Target) -> Bool {
        if case .address = target { return true }
        return false
    }
    
    private func keyboard(for target: Target) -> UIKeyboardType {
        switch target {
        case .phone: return .phonePad
        case .email: return .emailAddress
        default: return .default
        }
    }
    
    /// Same rule as the edit sheet: a changed field loses its review flag.
    private func apply(_ newValue: String, to target: Target) {
        var draft = card
        switch target {
        case .name: draft.name.value = newValue
        case .company: draft.company.value = newValue
        case .phone(let id):
            if let i = draft.phones.firstIndex(where: { $0.id == id }) { draft.phones[i].number = newValue }
        case .email: draft.email.value = newValue
        case .address: draft.address.value = newValue
        }
        onChange(CardEditLogic.applyingEdits(original: card, draft: draft))
    }
}
