import Foundation
import Observation

/// State machine for FAB → camera / photo → parse → 06 読み取り結果 → save.
/// Nothing is written to the store until `save(into:)`.
@MainActor
@Observable
final class ScanFlow {
    enum Stage: Equatable {
        case idle, camera, photoPicker, processing
        case result(BusinessCard)
        /// The result cover is dismissing; the camera opens from its onDismiss (`resumeCameraAfterRetake`).
        case retaking
    }
    
    enum ScanError: Equatable {
        case empty, failed
    }
    
    private(set) var stage: Stage = .idle
    /// Set when the last scan produced nothing or the camera failed; the list shows an alert and clears it.
    var error: ScanError? = nil
    
    /// True from the moment the camera sheet / photo picker is requested until the presentation layer
    /// reports it fully gone. A result that arrives in between is parked in `pendingResult`, because a
    /// fullScreenCover presented while a sheet is still dismissing is laid out without a safe area.
    private(set) var isPresentingPicker = false
    private var pendingResult: BusinessCard?
    
    private let parser = CardParser()
    private let resolver: TimeZoneResolver
    /// Which entry point produced the current scan; recorded with DEBUG fixtures.
    private var origin: CardFixture.Source = .paper
    
    init(resolver: TimeZoneResolver? = nil) {
        self.resolver = resolver ?? TimeZoneResolver()
    }
    
    var isShowingResult: Bool {
        if case .result = stage { return true }
        return false
    }
    
    var resultCard: BusinessCard? {
        if case .result(let card) = stage { return card }
        return nil
    }
    
    func startCamera() { origin = .paper; isPresentingPicker = true; stage = .camera }
    func startPhotoPicker() { origin = .image; isPresentingPicker = true; stage = .photoPicker }
    func beginProcessing() { stage = .processing }
    
    func cancel() {
        pendingResult = nil
        stage = .idle
    }
    
    /// Called by the presentation layer once the camera sheet or photo picker has finished dismissing.
    func presentationDidEnd() {
        isPresentingPicker = false
        if let card = pendingResult {
            pendingResult = nil
            stage = .result(card)
        }
    }
    
    /// Presenting the camera sheet while the result cover is still dismissing is refused by UIKit,
    /// so retake goes through `.retaking` and the presentation layer calls `resumeCameraAfterRetake()`.
    func retake() {
        guard case .result = stage else { return }
        stage = .retaking
    }
    
    func resumeCameraAfterRetake() {
        if stage == .retaking { origin = .paper; isPresentingPicker = true; stage = .camera }
    }
    
    /// Parses the OCR fragments and moves to the result stage.
    /// Returns false (and sets `error = .empty`) when nothing usable was read.
    @discardableResult
    func handleRecognized(items: [OCRItem]) -> Bool {
        var card = parser.parse(items: items)
        card.scannedAt = Date()
        #if DEBUG
        FixtureRecorder.shared.record(items: items, card: card, source: origin)
        #endif
        let hasContent = !card.name.isEmpty || !card.company.isEmpty || !card.email.isEmpty
            || !card.phones.isEmpty || !card.address.isEmpty
        guard hasContent else {
            error = .empty
            stage = .idle
            return false
        }
        CardStore.apply(resolver.resolve(for: card), to: &card)
        if isPresentingPicker {
            pendingResult = card
            stage = .processing
        } else {
            stage = .result(card)
        }
        return true
    }
    
    func handleFailed() {
        error = .failed
        stage = .idle
    }
    
    /// Replaces the draft shown on the result screen (after a single-field edit).
    func updateResult(_ card: BusinessCard) {
        guard case .result = stage else { return }
        stage = .result(card)
    }
    
    func save(into store: CardStore) {
        if case .result(let card) = stage {
            store.append(card)
        }
        stage = .idle
    }
}
