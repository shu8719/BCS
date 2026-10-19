import SwiftUI

/// Owns the card list: persistence (JSON in the app's Documents directory), time zone
/// resolution, multi-delete with a short Undo window, and review-state changes.
@MainActor
@Observable
final class CardStore {
    var cards: [BusinessCard] = []
    /// Legacy selection used by the old list screen; removed with it.
    var selectedIndex: Int? = nil
    private(set) var undoState: UndoState? = nil
    private var undoToken: UUID? = nil

    private let directory: URL
    private let legacyStorageKey = "business_cards_state_v1"

    private var jsonURL: URL {
        directory.appendingPathComponent("business_cards.json")
    }

    enum UndoOperation: Equatable {
        case deleteSingle
        case deleteMany(Int)
        case deleteAll
    }

    struct UndoState {
        let cards: [BusinessCard]
        let selectedIndex: Int?
        let operation: UndoOperation
    }

    nonisolated static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    init(directory: URL = CardStore.documentsDirectory) {
        self.directory = directory
        load()
        TimeZoneLookupTable.bundledZip.preload()
        TimeZoneLookupTable.bundledAreaCode.preload()
        resolveTimeZonesAsync(for: cards)
    }

    // MARK: - Reading

    func card(id: UUID) -> BusinessCard? {
        cards.first { $0.id == id }
    }

    var selectedCard: BusinessCard? {
        guard let idx = selectedIndex, cards.indices.contains(idx) else { return nil }
        return cards[idx]
    }

    var hasSelection: Bool { selectedCard != nil }

    // Returns a Binding suitable for EditCardView; saves and re-resolves timezone on each write.
    func binding(at index: Int) -> Binding<BusinessCard> {
        Binding(
            get: { [weak self] in
                guard let self, self.cards.indices.contains(index) else { return BusinessCard() }
                return self.cards[index]
            },
            set: { [weak self] newValue in
                guard let self, self.cards.indices.contains(index) else { return }
                self.cards[index] = newValue
                self.save()
                self.resolveTimeZonesAsync(for: [newValue])
            }
        )
    }

    // MARK: - Writing

    func append(_ card: BusinessCard) {
        cards.append(card)
        selectedIndex = cards.count - 1
        save()
        resolveTimeZonesAsync(for: [card])
    }

    /// Replaces the card with the same id, then re-resolves its time zone.
    func update(_ card: BusinessCard) {
        guard let idx = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[idx] = card
        save()
        resolveTimeZonesAsync(for: [card])
    }

    func markAllReviewed(id: UUID) {
        guard let idx = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[idx].markAllReviewed()
        save()
    }

    func select(at index: Int) {
        guard cards.indices.contains(index) else { return }
        selectedIndex = index
        save()
    }

    // MARK: - Deleting (each kind can be undone for 6 seconds)

    func deleteSelected() {
        guard let idx = selectedIndex, cards.indices.contains(idx) else { return }
        delete(at: idx)
    }

    func delete(at index: Int) {
        guard cards.indices.contains(index) else { return }
        saveUndo(operation: .deleteSingle)
        cards.remove(at: index)
        if let sel = selectedIndex {
            if sel == index {
                selectedIndex = cards.isEmpty ? nil : min(index, cards.count - 1)
            } else if sel > index {
                selectedIndex = sel - 1
            }
        }
        save()
    }

    func delete(id: UUID) {
        guard let idx = cards.firstIndex(where: { $0.id == id }) else { return }
        delete(at: idx)
    }

    func delete(ids: Set<UUID>) {
        let count = cards.filter { ids.contains($0.id) }.count
        guard count > 0 else { return }
        saveUndo(operation: .deleteMany(count))
        cards.removeAll { ids.contains($0.id) }
        selectedIndex = cards.isEmpty ? nil : 0
        save()
    }

    func resetAll() {
        guard !cards.isEmpty else { return }
        saveUndo(operation: .deleteAll)
        cards.removeAll()
        selectedIndex = nil
        save()
    }

    func restoreUndo() {
        guard let snapshot = undoState else { return }
        cards = snapshot.cards
        selectedIndex = snapshot.selectedIndex
        undoState = nil
        undoToken = nil
        save()
    }

    // MARK: - Private

    private func saveUndo(operation: UndoOperation) {
        undoState = UndoState(cards: cards, selectedIndex: selectedIndex, operation: operation)
        let token = UUID()
        undoToken = token
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard let self, self.undoToken == token else { return }
            self.undoState = nil
        }
    }

    private struct PersistedState: Codable {
        static let currentVersion = 2

        // Optional so files written before versioning (no "version" key) still decode.
        let version: Int?
        let cards: [BusinessCard]
        /// Written by v1; no longer used.
        let selectedIndex: Int?
    }

    private func save() {
        let state = PersistedState(version: PersistedState.currentVersion, cards: cards, selectedIndex: nil)
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: jsonURL, options: .atomic)
    }

    private func load() {
        // Migrate from UserDefaults on first run after update
        if !FileManager.default.fileExists(atPath: jsonURL.path),
           let legacy = UserDefaults.standard.data(forKey: legacyStorageKey) {
            try? legacy.write(to: jsonURL, options: .atomic)
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        }

        guard FileManager.default.fileExists(atPath: jsonURL.path) else { return }

        do {
            let data = try Data(contentsOf: jsonURL)
            let state = try JSONDecoder().decode(PersistedState.self, from: data)
            if let version = state.version, version > PersistedState.currentVersion {
                throw CocoaError(.fileReadUnsupportedScheme,
                                 userInfo: [NSLocalizedDescriptionKey: "state version \(version) is newer than supported \(PersistedState.currentVersion)"])
            }
            cards = state.cards
            if let idx = state.selectedIndex, cards.indices.contains(idx) {
                selectedIndex = idx
            } else {
                selectedIndex = cards.isEmpty ? nil : 0
            }
        } catch {
            // Do not let a subsequent save() overwrite data we could not read:
            // move the file aside so it survives, then start with an empty list.
            setAsideUnreadableStateFile(reason: error)
        }
    }

    private func setAsideUnreadableStateFile(reason: Error) {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupURL = directory.appendingPathComponent("business_cards.unreadable-\(stamp).json")
        do {
            try FileManager.default.moveItem(at: jsonURL, to: backupURL)
            print("CardStore: could not read saved cards (\(reason)); kept file as \(backupURL.lastPathComponent)")
        } catch {
            print("CardStore: could not read saved cards (\(reason)) and failed to set the file aside: \(error)")
        }
    }

    /// Writes a resolution into the card, including the ZIP/area-code conflict review flag.
    static func apply(_ resolution: TimeZoneResolution?, to card: inout BusinessCard) {
        if let r = resolution {
            card.timeZone = r.zone
            card.timeZoneId = r.identifier
            card.timeZoneSource = r.source
            if r.conflict, card.address.reviewReason == nil {
                card.address.reviewReason = .timeZoneConflict
            } else if !r.conflict, card.address.reviewReason == .timeZoneConflict {
                card.address.reviewReason = nil
            }
        } else {
            card.timeZone = nil
            card.timeZoneId = ""
            card.timeZoneSource = nil
            if card.address.reviewReason == .timeZoneConflict { card.address.reviewReason = nil }
        }
    }

    private func resolveTimeZonesAsync(for snapshot: [BusinessCard]) {
        guard !snapshot.isEmpty else { return }
        Task {
            let updates = await Task.detached(priority: .utility) {
                TimeZoneResolver.resolveUpdates(for: snapshot)
            }.value
            for update in updates {
                guard let idx = self.cards.firstIndex(where: { $0.id == update.cardID }) else { continue }
                Self.apply(update.resolution, to: &self.cards[idx])
            }
            if !updates.isEmpty { self.save() }
        }
    }
}
