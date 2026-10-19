import SwiftUI
import PhotosUI

/// 01 名刺一覧: brand bar, search, filter chips, cards grouped by week, scan FAB.
struct CardListView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(CardStore.self) private var store
    
    @State private var query = CardListQuery()
    @State private var isSelecting = false
    @State private var selected: Set<UUID> = []
    @State private var showSortDialog = false
    @State private var showCompanyDialog = false
    @State private var showZoneDialog = false
    @State private var confirmDeleteSelected = false
    @State private var exportItem: ExportItem?
    
    private struct ExportItem: Identifiable {
        let id = UUID()
        let url: URL
    }
    
    @State private var flow = ScanFlow()
    @State private var showScanMenu = false
    @State private var pickedPhoto: PhotosPickerItem?
    
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
                
                if flow.stage == .processing {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView().tint(.white).scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                if !isSelecting {
                    ScanFAB(label: L10n.t(.scan, lang: lang)) { showScanMenu = true }
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    if store.undoState != nil { undoBar }
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
            .confirmationDialog(L10n.t(.sortTitle, lang: lang), isPresented: $showSortDialog, titleVisibility: .visible) {
                Button(L10n.t(.sortNewest, lang: lang)) { query.sort = .scannedAtDesc }
                Button(L10n.t(.sortName, lang: lang)) { query.sort = .nameAsc }
                Button(L10n.t(.sortCompany, lang: lang)) { query.sort = .companyAsc }
            }
            .confirmationDialog(L10n.t(.filterCompany, lang: lang), isPresented: $showCompanyDialog, titleVisibility: .visible) {
                Button(L10n.t(.allCompanies, lang: lang)) { query.company = nil }
                ForEach(CardListFilter.companies(in: store.cards), id: \.self) { company in
                    Button(company) { query.company = company }
                }
            }
            .confirmationDialog(L10n.t(.filterTimeZone, lang: lang), isPresented: $showZoneDialog, titleVisibility: .visible) {
                Button(L10n.t(.allTimeZones, lang: lang)) { query.zone = nil }
                ForEach(USTimeZone.allCases, id: \.self) { zone in
                    Button(zone.rawValue) { query.zone = zone }
                }
            }
            .confirmationDialog(L10n.t(.scan, lang: lang), isPresented: $showScanMenu, titleVisibility: .hidden) {
                Button(L10n.t(.scanWithCamera, lang: lang)) { flow.startCamera() }
                Button(L10n.t(.scanFromPhoto, lang: lang)) { flow.startPhotoPicker() }
            }
            .sheet(isPresented: Binding(get: { flow.stage == .camera }, set: { if !$0, flow.stage == .camera { flow.cancel() } })) {
                ScannerView(
                    onRecognized: { items in flow.handleRecognized(items: items) },
                    onFailed: { flow.handleFailed() },
                    onStartProcessing: { flow.beginProcessing() }
                )
            }
            .photosPicker(isPresented: Binding(get: { flow.stage == .photoPicker }, set: { if !$0, flow.stage == .photoPicker { flow.cancel() } }),
                          selection: $pickedPhoto, matching: .images)
            .onChange(of: pickedPhoto) { _, item in
                guard let item else { return }
                pickedPhoto = nil
                flow.beginProcessing()
                Task {
                    if let items = await PhotoImport.recognize(item) {
                        flow.handleRecognized(items: items)
                    } else {
                        flow.handleFailed()
                    }
                }
            }
            .fullScreenCover(isPresented: Binding(get: { flow.isShowingResult }, set: { if !$0, flow.isShowingResult { flow.cancel() } })) {
                if let card = flow.resultCard {
                    ScanResultView(
                        card: card,
                        onChange: { flow.updateResult($0) },
                        onSave: { flow.save(into: store) },
                        onRetake: { flow.retake() },
                        onCancel: { flow.cancel() }
                    )
                }
            }
            .alert(
                Text(flow.error == .failed ? L10n.t(.scanFailedTitle, lang: lang) : L10n.t(.scanEmptyTitle, lang: lang)),
                isPresented: Binding(get: { flow.error != nil }, set: { if !$0 { flow.error = nil } }),
                presenting: flow.error
            ) { _ in
                Button(L10n.t(.ok, lang: lang), role: .cancel) {}
            } message: { error in
                Text(error == .failed ? L10n.t(.scanFailedMessage, lang: lang) : L10n.t(.scanEmptyMessage, lang: lang))
            }
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
            IconButton(.sort) { showSortDialog = true }
            IconButton(.checklist) { isSelecting = true }
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
                FilterChip(query.company ?? L10n.t(.filterCompany, lang: lang), trailing: .expandMore,
                           selected: query.company != nil) {
                    showCompanyDialog = true
                }
                FilterChip(query.zone?.rawValue ?? L10n.t(.filterTimeZone, lang: lang), trailing: .expandMore,
                           selected: query.zone != nil) {
                    showZoneDialog = true
                }
            }
            .padding(.horizontal, 16)
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
    
    // MARK: - Undo
    
    private var undoBar: some View {
        HStack(spacing: 12) {
            if let state = store.undoState {
                Text(undoMessage(for: state.operation))
                    .textStyle(.bodySmall)
                    .foregroundStyle(M3.onSurfaceVariant)
                Spacer()
                BCSButton(L10n.t(.undo, lang: lang), style: .tonal) { store.restoreUndo() }
            }
        }
        .padding(12)
        .background(M3.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private func undoMessage(for operation: CardStore.UndoOperation) -> String {
        switch operation {
        case .deleteSingle:          return L10n.t(.undoDeletedMessage, lang: lang)
        case .deleteMany(let count): return L10n.t(.undoDeletedManyMessage, lang: lang, count)
        case .deleteAll:             return L10n.t(.undoResetMessage, lang: lang)
        }
    }
}
