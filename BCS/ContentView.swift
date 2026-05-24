import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(CardStore.self) private var store

    @State private var showScanner = false
    @State private var showEditSheet = false
    @State private var scanDraft = BusinessCard()
    @State private var exportItem: ExportItem?
    @State private var activeAlert: ActiveAlert?
    @State private var isProcessing = false

    private let bgTop      = Color(red: 0.95, green: 0.97, blue: 1.00)
    private let bgBottom   = Color(red: 0.98, green: 0.95, blue: 0.96)
    private let accent     = Color(red: 0.16, green: 0.46, blue: 0.86)
    private let accentSoft = Color(red: 0.84, green: 0.90, blue: 1.00)

    private enum ActiveAlert: Identifiable {
        case deleteSelected, resetAll, scanEmpty, scanFailed
        var id: Int {
            switch self {
            case .deleteSelected: return 0
            case .resetAll:       return 1
            case .scanEmpty:      return 2
            case .scanFailed:     return 3
            }
        }
    }

    private struct ExportItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [bgTop, bgBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            List {
                headerView
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 0, trailing: 20))
                summaryCard
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 10, trailing: 20))
                if !store.cards.isEmpty {
                    ForEach(Array(store.cards.enumerated()), id: \.element.id) { idx, item in
                        Button { store.select(at: idx) } label: {
                            cardRow(item, isSelected: idx == store.selectedIndex)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.delete(at: idx)
                            } label: {
                                Label(L10n.t(.deleteAction, lang: settings.language), systemImage: "trash")
                            }
                        }
                    }
                } else {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)

            if isProcessing {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .animation(.easeInOut(duration: 0.2), value: store.undoState != nil)
        .sheet(isPresented: $showScanner) {
            ScannerView(
                card: $scanDraft,
                onFinish: {
                    isProcessing = false
                    store.append(scanDraft)
                    showEditSheet = true
                },
                onEmpty:  { isProcessing = false; activeAlert = .scanEmpty },
                onFailed: { isProcessing = false; activeAlert = .scanFailed },
                onStartProcessing: { isProcessing = true }
            )
        }
        .sheet(isPresented: $showEditSheet) {
            if let idx = store.selectedIndex, store.cards.indices.contains(idx) {
                EditCardView(card: store.binding(at: idx))
            }
        }
        .sheet(item: $exportItem) { item in
            ShareSheet(items: [item.url])
                .onDisappear { try? FileManager.default.removeItem(at: item.url) }
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .deleteSelected:
                return Alert(
                    title: Text(L10n.t(.deleteSelectedTitle, lang: settings.language)),
                    message: Text(L10n.t(.deleteSelectedMessage, lang: settings.language)),
                    primaryButton: .destructive(Text(L10n.t(.deleteAction, lang: settings.language))) {
                        store.deleteSelected()
                    },
                    secondaryButton: .cancel(Text(L10n.t(.cancel, lang: settings.language)))
                )
            case .resetAll:
                return Alert(
                    title: Text(L10n.t(.resetAllTitle, lang: settings.language)),
                    message: Text(L10n.t(.resetAllMessage, lang: settings.language)),
                    primaryButton: .destructive(Text(L10n.t(.resetAction, lang: settings.language))) {
                        store.resetAll()
                    },
                    secondaryButton: .cancel(Text(L10n.t(.cancel, lang: settings.language)))
                )
            case .scanEmpty:
                return Alert(
                    title: Text(L10n.t(.scanEmptyTitle, lang: settings.language)),
                    message: Text(L10n.t(.scanEmptyMessage, lang: settings.language)),
                    dismissButton: .default(Text(L10n.t(.ok, lang: settings.language)))
                )
            case .scanFailed:
                return Alert(
                    title: Text(L10n.t(.scanFailedTitle, lang: settings.language)),
                    message: Text(L10n.t(.scanFailedMessage, lang: settings.language)),
                    dismissButton: .default(Text(L10n.t(.ok, lang: settings.language)))
                )
            }
        }
    }

    // MARK: - Info rows

    private func infoRow(_ title: String, _ value: String, iconAsset: String, badge: TimeZoneBadge? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(iconAsset)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                Text(title)
                    .font(.custom("AvenirNext-Medium", size: 11))
                    .foregroundColor(.secondary)
            }
            if let badge {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(value.isEmpty ? "Unknown" : value)
                        .font(.custom("AvenirNext-Regular", size: 16))
                        .foregroundColor(.primary)
                        .layoutPriority(1)
                    Spacer(minLength: 4)
                    timeZoneBadge(badge)
                }
            } else {
                Text(value.isEmpty ? "Unknown" : value)
                    .font(.custom("AvenirNext-Regular", size: 16))
                    .foregroundColor(.primary)
            }
        }
    }

    private func displayPhones(_ phones: [LabeledNumber]) -> String {
        phones.isEmpty ? "" : phones.map(\.number).joined(separator: " / ")
    }

    private var currentCard: BusinessCard { store.selectedCard ?? BusinessCard() }

    private func displayTitle(_ card: BusinessCard) -> String {
        if !card.name.isEmpty    { return card.name }
        if !card.company.isEmpty { return card.company }
        if !card.email.isEmpty   { return card.email }
        return "Unknown"
    }

    // MARK: - Header / Summary

    private var headerView: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t(.title, lang: settings.language))
                    .font(.custom("AvenirNext-DemiBold", size: 32))
                    .foregroundColor(.primary)
                Text(cardCountText())
                    .font(.custom("AvenirNext-Regular", size: 14))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private func cardCountText() -> String {
        let count = store.cards.count
        switch resolvedLanguage() {
        case .japanese:         return "\(count)件"
        case .english, .system: return "\(count) cards"
        }
    }

    private func resolvedLanguage() -> AppSettings.Language {
        if settings.language != .system { return settings.language }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("ja") ? .japanese : .english
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            infoRow(L10n.t(.name,    lang: settings.language), currentCard.name,                  iconAsset: "IconPerson")
            infoRow(L10n.t(.company, lang: settings.language), currentCard.company,               iconAsset: "IconBuilding")
            infoRow(L10n.t(.phone,   lang: settings.language), displayPhones(currentCard.phones), iconAsset: "IconPhone")
            infoRow(L10n.t(.email,   lang: settings.language), currentCard.email,                 iconAsset: "IconEmail")
            infoRow(L10n.t(.address, lang: settings.language), currentCard.address,               iconAsset: "IconMap", badge: currentTimeZoneBadge)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.75))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.6), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 8)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(L10n.t(.emptyCardsMessage, lang: settings.language))
                .font(.custom("AvenirNext-Regular", size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundColor(accent.opacity(0.2))
        )
    }

    private func cardRow(_ card: BusinessCard, isSelected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle(card))
                    .font(.custom("AvenirNext-DemiBold", size: 16))
                    .foregroundColor(.primary)
                if !card.company.isEmpty {
                    Text(card.company)
                        .font(.custom("AvenirNext-Regular", size: 12))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(accent)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? accentSoft.opacity(0.8) : Color.white.opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? accent.opacity(0.4) : Color.white.opacity(0.6), lineWidth: 1))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 4)
    }

    // MARK: - Bottom bar

    private var undoBar: some View {
        HStack(spacing: 12) {
            if let state = store.undoState {
                Text(undoMessage(for: state.operation))
                    .font(.custom("AvenirNext-Regular", size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Button(L10n.t(.undo, lang: settings.language)) {
                    store.restoreUndo()
                }
                .buttonStyle(PillButtonStyle(background: accentSoft, foreground: accent))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.7)))
    }

    private func undoMessage(for operation: CardStore.UndoOperation) -> String {
        switch operation {
        case .deleteSingle: return L10n.t(.undoDeletedMessage, lang: settings.language)
        case .deleteAll:    return L10n.t(.undoResetMessage,   lang: settings.language)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button(L10n.t(.scan, lang: settings.language)) {
                    scanDraft = BusinessCard()
                    showScanner = true
                }
                .buttonStyle(PillButtonStyle(background: accent, foreground: .white))

                Button(L10n.t(.edit, lang: settings.language)) {
                    showEditSheet = true
                }
                .buttonStyle(PillButtonStyle(background: Color.white.opacity(0.9), foreground: accent))
                .disabled(!store.hasSelection)

                Button {
                    exportCSV()
                } label: {
                    HStack(spacing: 6) {
                        Image("IconExport")
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text(L10n.t(.exportCSV, lang: settings.language))
                    }
                }
                .buttonStyle(PillButtonStyle(background: Color.white.opacity(0.9), foreground: accent))
                .disabled(store.cards.isEmpty)
            }

            HStack(spacing: 10) {
                Button(L10n.t(.deleteSelected, lang: settings.language)) {
                    activeAlert = .deleteSelected
                }
                .buttonStyle(PillButtonStyle(background: Color.white.opacity(0.9), foreground: Color.red))
                .disabled(!store.hasSelection)

                Button(L10n.t(.resetAllCards, lang: settings.language)) {
                    activeAlert = .resetAll
                }
                .buttonStyle(PillButtonStyle(background: Color.white.opacity(0.9), foreground: Color.red))
                .disabled(store.cards.isEmpty)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if store.undoState != nil { undoBar }
            actionButtons
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            LinearGradient(colors: [bgBottom.opacity(0.0), bgBottom.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private struct PillButtonStyle: ButtonStyle {
        let background: Color
        let foreground: Color
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.custom("AvenirNext-DemiBold", size: 14))
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(background.opacity(configuration.isPressed ? 0.85 : 1.0))
                .foregroundColor(foreground)
                .clipShape(Capsule())
        }
    }

    // MARK: - Export

    private func exportCSV() {
        guard !store.cards.isEmpty else { return }
        let csv = makeCSV(cards: store.cards)
        let fileName = "business_cards_\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            exportItem = ExportItem(url: url)
        } catch {
            print("CSV write error: \(error)")
        }
    }

    private func makeCSV(cards: [BusinessCard]) -> String {
        func escape(_ s: String) -> String {
            if s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") {
                return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return s
        }
        let lang = settings.language
        let headers = [L10n.t(.name, lang: lang), L10n.t(.company, lang: lang),
                       L10n.t(.address, lang: lang), L10n.t(.phone, lang: lang),
                       L10n.t(.email, lang: lang), L10n.t(.timeZone, lang: lang)]
        var rows = [headers.map(escape).joined(separator: ",")]
        for c in cards {
            let phones = c.phones.map(\.number).joined(separator: " / ")
            rows.append([c.name, c.company, c.address, phones, c.email, c.timeZoneCode]
                .map(escape).joined(separator: ","))
        }
        // UTF-8 BOM + CRLF for Excel compatibility
        return "\u{FEFF}" + rows.joined(separator: "\r\n")
    }

    // MARK: - Timezone badge (UI only)

    private struct TimeZoneBadge {
        let text: String
        let color: Color
    }

    private var currentTimeZoneBadge: TimeZoneBadge? {
        guard !currentCard.timeZoneCode.isEmpty else { return nil }
        return TimeZoneBadge(text: currentCard.timeZoneCode, color: timeZoneColor(for: currentCard.timeZoneCode))
    }

    private func timeZoneBadge(_ badge: TimeZoneBadge) -> some View {
        Text(badge.text)
            .font(.custom("AvenirNext-DemiBold", size: 12))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(badge.color.opacity(0.18))
            .foregroundColor(badge.color)
            .clipShape(Capsule())
    }

    private func timeZoneColor(for code: String) -> Color {
        switch code {
        case "PST": return .red
        case "MST": return .blue
        case "CST": return .green
        case "EST": return Color(red: 0.95, green: 0.78, blue: 0.15)
        default:    return .gray
        }
    }
}
