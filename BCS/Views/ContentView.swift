import SwiftUI

/// Card list screen: summary of the selected card, the list, and the scan / edit / export actions.
struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(CardStore.self) private var store

    @State private var showScanner = false
    @State private var showEditSheet = false
    @State private var showScanDraftEditor = false
    @State private var scanDraft = BusinessCard()
    @State private var exportItem: ExportItem?
    @State private var activeAlert: ActiveAlert?
    @State private var isProcessing = false

    private enum ActiveAlert {
        case deleteSelected, resetAll, scanEmpty, scanFailed
    }

    private struct ExportItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            List {
                headerView
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 0, trailing: 20))
                CardSummaryView(card: store.selectedCard ?? BusinessCard())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 10, trailing: 20))
                if !store.cards.isEmpty {
                    ForEach(Array(store.cards.enumerated()), id: \.element.id) { idx, item in
                        Button { store.select(at: idx) } label: {
                            CardRowView(card: item, isSelected: idx == store.selectedIndex)
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
                    showScanDraftEditor = true
                },
                onEmpty:  { isProcessing = false; activeAlert = .scanEmpty },
                onFailed: { isProcessing = false; activeAlert = .scanFailed },
                onStartProcessing: { isProcessing = true }
            )
        }
        .sheet(isPresented: $showScanDraftEditor) {
            // The scanned card is stored only when the user taps Save; Cancel discards it.
            EditCardView(card: $scanDraft, onSave: { store.append($0) })
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
        .alert(
            Text(activeAlert.map(alertTitle(for:)) ?? ""),
            isPresented: Binding(
                get: { activeAlert != nil },
                set: { if !$0 { activeAlert = nil } }
            ),
            presenting: activeAlert
        ) { alert in
            switch alert {
            case .deleteSelected:
                Button(L10n.t(.deleteAction, lang: settings.language), role: .destructive) { store.deleteSelected() }
                Button(L10n.t(.cancel, lang: settings.language), role: .cancel) {}
            case .resetAll:
                Button(L10n.t(.resetAction, lang: settings.language), role: .destructive) { store.resetAll() }
                Button(L10n.t(.cancel, lang: settings.language), role: .cancel) {}
            case .scanEmpty, .scanFailed:
                Button(L10n.t(.ok, lang: settings.language), role: .cancel) {}
            }
        } message: { alert in
            Text(alertMessage(for: alert))
        }
    }

    // MARK: - Header / empty state

    private var headerView: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t(.title, lang: settings.language))
                    .font(.custom("AvenirNext-DemiBold", size: 32))
                    .foregroundStyle(.primary)
                Text(cardCountText)
                    .font(.custom("AvenirNext-Regular", size: 14))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var cardCountText: String {
        let count = store.cards.count
        switch L10n.resolve(settings.language) {
        case .japanese:         return "\(count)件"
        case .english, .system: return "\(count) cards"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(L10n.t(.emptyCardsMessage, lang: settings.language))
                .font(.custom("AvenirNext-Regular", size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(Theme.accent.opacity(0.2))
        )
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if store.undoState != nil { undoBar }
            actionButtons
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            LinearGradient(colors: [Theme.bgBottom.opacity(0.0), Theme.bgBottom.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private var undoBar: some View {
        HStack(spacing: 12) {
            if let state = store.undoState {
                Text(undoMessage(for: state.operation))
                    .font(.custom("AvenirNext-Regular", size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L10n.t(.undo, lang: settings.language)) {
                    store.restoreUndo()
                }
                .buttonStyle(PillButtonStyle(background: Theme.accentSoft, foreground: Theme.accent))
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
                .buttonStyle(PillButtonStyle(background: Theme.accent, foreground: .white))

                Button(L10n.t(.edit, lang: settings.language)) {
                    showEditSheet = true
                }
                .buttonStyle(PillButtonStyle(background: Color.white.opacity(0.9), foreground: Theme.accent))
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
                .buttonStyle(PillButtonStyle(background: Color.white.opacity(0.9), foreground: Theme.accent))
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

    // MARK: - Alerts

    private func alertTitle(for alert: ActiveAlert) -> String {
        switch alert {
        case .deleteSelected: return L10n.t(.deleteSelectedTitle, lang: settings.language)
        case .resetAll:       return L10n.t(.resetAllTitle,       lang: settings.language)
        case .scanEmpty:      return L10n.t(.scanEmptyTitle,      lang: settings.language)
        case .scanFailed:     return L10n.t(.scanFailedTitle,     lang: settings.language)
        }
    }

    private func alertMessage(for alert: ActiveAlert) -> String {
        switch alert {
        case .deleteSelected: return L10n.t(.deleteSelectedMessage, lang: settings.language)
        case .resetAll:       return L10n.t(.resetAllMessage,       lang: settings.language)
        case .scanEmpty:      return L10n.t(.scanEmptyMessage,      lang: settings.language)
        case .scanFailed:     return L10n.t(.scanFailedMessage,     lang: settings.language)
        }
    }

    // MARK: - Export

    private func exportCSV() {
        guard !store.cards.isEmpty else { return }
        do {
            exportItem = ExportItem(url: try CSVExporter.writeTemporaryFile(cards: store.cards, lang: settings.language))
        } catch {
            print("CSV write error: \(error)")
        }
    }
}
