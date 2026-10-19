import SwiftUI

@MainActor
@Observable
final class CardStore {
    var cards: [BusinessCard] = []
    var selectedIndex: Int? = nil
    private(set) var undoState: UndoState? = nil
    private var undoToken: UUID? = nil

    private let legacyStorageKey = "business_cards_state_v1"

    private var jsonURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("business_cards.json")
    }

    enum UndoOperation { case deleteSingle, deleteAll }

    struct UndoState {
        let cards: [BusinessCard]
        let selectedIndex: Int?
        let operation: UndoOperation
    }

    init() {
        load()
        TimeZoneLookupTable.bundledZip.preload()
        TimeZoneLookupTable.bundledAreaCode.preload()
        resolveTimeZonesAsync(for: cards)
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

    func append(_ card: BusinessCard) {
        cards.append(card)
        selectedIndex = cards.count - 1
        save()
        resolveTimeZonesAsync(for: [card])
    }

    func select(at index: Int) {
        guard cards.indices.contains(index) else { return }
        selectedIndex = index
        save()
    }

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
        static let currentVersion = 1

        // Optional so files written before versioning (no "version" key) still decode.
        let version: Int?
        let cards: [BusinessCard]
        let selectedIndex: Int?
    }

    private func save() {
        let state = PersistedState(version: PersistedState.currentVersion, cards: cards, selectedIndex: selectedIndex)
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
        let backupURL = jsonURL.deletingLastPathComponent()
            .appendingPathComponent("business_cards.unreadable-\(stamp).json")
        do {
            try FileManager.default.moveItem(at: jsonURL, to: backupURL)
            print("CardStore: could not read saved cards (\(reason)); kept file as \(backupURL.lastPathComponent)")
        } catch {
            print("CardStore: could not read saved cards (\(reason)) and failed to set the file aside: \(error)")
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
                self.cards[idx].timeZoneCode = update.code
                self.cards[idx].timeZoneId = update.identifier
                self.cards[idx].timeZoneSourceAddress = update.sourceKey
            }
            if !updates.isEmpty { self.save() }
        }
    }
}
