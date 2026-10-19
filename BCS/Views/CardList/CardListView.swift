import SwiftUI

/// 01 名刺一覧: brand bar, search, filter chips, cards grouped by week, scan FAB.
struct CardListView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(CardStore.self) private var store
    
    @State private var query = CardListQuery()
    @State private var isSelecting = false
    @State private var selected: Set<UUID> = []
    @State private var confirmDeleteSelected = false
    @State private var exportItem: ExportItem?
    
    private struct ExportItem: Identifiable {
        let id = UUID()
        let url: URL
    }
    
    @State private var flow = ScanFlow()
    @State private var fabMenuOpen = false
    
    private var lang: AppSettings.Language { settings.language }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                M3.surfaceContainerLow.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if isSelecting {
                            selectionTopBar
                            selectionHeader
                        } else {
                            topBar
                            SearchBar(text: $query.search, placeholder: L10n.t(.searchPlaceholder, lang: lang))
                                .padding(.horizontal, 16)
                            filterChips
                        }
                        listBody
                        Color.clear.frame(height: 96)
                    }
                    .padding(.top, 4)
                }
                .scrollDismissesKeyboard(.interactively)
                
                if !isSelecting {
                    ScanFABMenu(
                        isOpen: $fabMenuOpen,
                        label: L10n.t(.scan, lang: lang),
                        photoLabel: L10n.t(.scanFromPhoto, lang: lang),
                        cameraLabel: L10n.t(.scanWithCamera, lang: lang),
                        onPhoto: { flow.startPhotoPicker() },
                        onCamera: { flow.startCamera() }
                    )
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            #if DEBUG
            .onAppear {
                if DebugLaunch.showsScanResultSample, flow.stage == .idle {
                    flow.handleRecognized(items: DebugLaunch.sampleItems)
                }
            }
            #endif
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    if let state = store.undoState {
                        UndoBar(operation: state.operation) { store.restoreUndo() }
                    }
                    if isSelecting { selectionBottomBar }
                }
            }
            .confirmationDialog(L10n.t(.deleteCountTitle, lang: lang, selected.count),
                                isPresented: $confirmDeleteSelected, titleVisibility: .visible) {
                Button(L10n.t(.deleteAction, lang: lang), role: .destructive) { deleteSelected() }
                Button(L10n.t(.cancel, lang: lang), role: .cancel) {}
            }
            .sheet(item: $exportItem) { item in
                ShareSheet(items: [item.url])
                    .onDisappear { try? FileManager.default.removeItem(at: item.url) }
            }
            .animation(.easeInOut(duration: 0.2), value: store.undoState != nil)
            .navigationDestination(for: UUID.self) { id in
                CardDetailView(cardID: id)
            }
            .scanFlowPresentation(flow)
        }
    }
    
    // MARK: - Selection mode (02)
    
    private var selectionTopBar: some View {
        HStack(spacing: 4) {
            IconButton(.close) { exitSelection() }
            Text(L10n.t(.selectedCount, lang: lang, selected.count))
                .textStyle(.titleLarge)
                .foregroundStyle(M3.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
            IconButton(.download) { exportSelected() }
            IconButton(.delete) { confirmDeleteSelected = true }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }
    
    private var selectionHeader: some View {
        HStack {
            Text(L10n.t(.tapToToggle, lang: lang))
                .textStyle(.bodyMedium)
                .foregroundStyle(M3.onSurfaceVariant)
            Spacer()
            BCSButton(L10n.t(.selectAll, lang: lang), style: .text) {
                selected = Set(CardListFilter.apply(query, to: store.cards).map(\.id))
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
    }
    
    private var selectionBottomBar: some View {
        HStack(spacing: 12) {
            BCSButton(L10n.t(.exportSelectedCSV, lang: lang), icon: .download, style: .tonal, fullWidth: true) {
                exportSelected()
            }
            BCSButton(L10n.t(.deleteAction, lang: lang), icon: .delete, style: .danger, fullWidth: true) {
                confirmDeleteSelected = true
            }
            .disabled(selected.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(M3.surfaceContainer.ignoresSafeArea())
    }
    
    private func exitSelection() {
        isSelecting = false
        selected = []
    }
    
    private func exportSelected() {
        let cards = store.cards.filter { selected.contains($0.id) }
        guard !cards.isEmpty else { return }
        do {
            exportItem = ExportItem(url: try CSVExporter.writeTemporaryFile(cards: cards, lang: lang))
        } catch {
            print("CSV write error: \(error)")
        }
    }
    
    private func deleteSelected() {
        store.delete(ids: selected)
        exitSelection()
    }
    
    // MARK: - Top bar / chips
    
    private var topBar: some View {
        HStack(spacing: 0) {
            BrandWordmark()
            Spacer(minLength: 10)
            sortMenu
            IconButton(.checklist) { fabMenuOpen = false; isSelecting = true }
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 10)
    }
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                let all = store.cards.count
                let review = store.cards.filter(\.needsReview).count
                FilterChip("\(L10n.t(.filterAll, lang: lang)) \(all)", leading: query.needsReviewOnly ? nil : .check,
                           selected: !query.needsReviewOnly) {
                    query.needsReviewOnly = false
                }
                FilterChip("\(L10n.t(.filterNeedsReview, lang: lang)) \(review)", leading: .warning,
                           selected: query.needsReviewOnly, tint: .warning) {
                    query.needsReviewOnly.toggle()
                }
                zoneMenu
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Menus (Figma 17-684 / 17-605, rendered with the system Menu)
    
    /// Sort order; the Picker inside the Menu puts a check on the current choice.
    private var sortMenu: some View {
        Menu {
            Picker("", selection: $query.sort) {
                Text(L10n.t(.sortNewest, lang: lang)).tag(CardSort.scannedAtDesc)
                Text(L10n.t(.sortOldest, lang: lang)).tag(CardSort.scannedAtAsc)
                Text(L10n.t(.sortName, lang: lang)).tag(CardSort.nameAsc)
                Text(L10n.t(.sortCompany, lang: lang)).tag(CardSort.companyAsc)
            }
        } label: {
            IconView(.sort, size: 24, color: M3.onSurface)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
    }
    
    /// Time zone filter with a card count per zone (counts cover every card, not the current filter).
    /// One Text per item: a Menu Picker splits multiple Texts into separate rows and the tag lands on the last one.
    private var zoneMenu: some View {
        Menu {
            Picker("", selection: $query.zone) {
                Text("\(L10n.t(.allTimeZones, lang: lang))（\(store.cards.count)）")
                    .tag(USTimeZone?.none)
                Divider()
                ForEach(USTimeZone.allCases, id: \.self) { zone in
                    let count = store.cards.filter { $0.timeZone == zone }.count
                    Text("\(zoneName(zone))（\(zone.rawValue)）・\(L10n.t(.countSuffix, lang: lang, count))")
                        .tag(USTimeZone?.some(zone))
                        .disabled(count == 0)
                }
            }
        } label: {
            FilterChipLabel(query.zone?.rawValue ?? L10n.t(.filterTimeZone, lang: lang),
                            trailing: .expandMore, selected: query.zone != nil)
        }
    }
    
    private func zoneName(_ zone: USTimeZone) -> String {
        switch zone {
        case .est: return L10n.t(.tzShortEST, lang: lang)
        case .cst: return L10n.t(.tzShortCST, lang: lang)
        case .mst: return L10n.t(.tzShortMST, lang: lang)
        case .pst: return L10n.t(.tzShortPST, lang: lang)
        }
    }
    
    // MARK: - List
    
    private var listBody: some View {
        let cards = CardListFilter.apply(query, to: store.cards)
        let groups = CardListFilter.group(cards, now: Date(), calendar: .current)
        return VStack(alignment: .leading, spacing: 12) {
            if store.cards.isEmpty {
                emptyState
            } else {
                ForEach(groups, id: \.group) { entry in
                    SectionHeader(groupTitle(entry.group),
                                  trailing: L10n.t(.countSuffix, lang: lang, entry.cards.count))
                    GroupedRows(cornerRadius: 16) {
                        ForEach(entry.cards) { card in
                            row(for: card)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func row(for card: BusinessCard) -> some View {
        TimelineView(.everyMinute) { context in
            if isSelecting {
                Button {
                    toggleSelection(card.id)
                } label: {
                    ContactRow(card: card, isSelecting: true, isSelected: selected.contains(card.id), now: context.date)
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(value: card.id) {
                    ContactRow(card: card, now: context.date)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                        isSelecting = true
                        selected = [card.id]
                    }
                )
            }
        }
    }
    
    private func toggleSelection(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }
    
    private func groupTitle(_ group: CardGroup) -> String {
        switch group {
        case .thisWeek: return L10n.t(.groupThisWeek, lang: lang)
        case .earlier:  return L10n.t(.groupEarlier, lang: lang)
        }
    }
    
    private var emptyState: some View {
        Text(L10n.t(.emptyCardsMessage, lang: lang))
            .textStyle(.bodyMedium)
            .foregroundStyle(M3.onSurfaceVariant)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(M3.outlineVariant)
            )
    }
    
}
