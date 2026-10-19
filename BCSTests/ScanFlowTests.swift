import XCTest
@testable import BCS

@MainActor
final class ScanFlowTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanFlowTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func resultCard(_ flow: ScanFlow) -> BusinessCard? {
        if case .result(let card) = flow.stage { return card }
        return nil
    }

    func testRecognizedItemsProduceResultWithScanDate() {
        let flow = ScanFlow(resolver: repoTimeZoneResolver())
        let before = Date()
        XCTAssertTrue(flow.handleRecognized(items: sampleUSCardItems()))
        let card = resultCard(flow)
        XCTAssertEqual(card?.name.value, "John Smith")
        XCTAssertEqual(card?.timeZone, .pst)                      // CA 95110, resolved before showing the result
        XCTAssertEqual(card?.timeZoneSource, .zip("95110"))
        XCTAssertLessThan(abs((card?.scannedAt ?? .distantPast).timeIntervalSince(before)), 2)
    }

    func testEmptyRecognitionReturnsFalseAndIdles() {
        let flow = ScanFlow(resolver: repoTimeZoneResolver())
        flow.startCamera()
        XCTAssertFalse(flow.handleRecognized(items: []))
        XCTAssertEqual(flow.stage, .idle)
        XCTAssertEqual(flow.error, .empty)
    }

    func testSaveAppendsAndResets() {
        let store = CardStore(directory: directory)
        let flow = ScanFlow(resolver: repoTimeZoneResolver())
        _ = flow.handleRecognized(items: sampleUSCardItems())
        flow.save(into: store)
        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.cards.first?.name.value, "John Smith")
        XCTAssertEqual(flow.stage, .idle)
    }

    func testRetakeWaitsForResultDismissalBeforeOpeningCamera() {
        let flow = ScanFlow(resolver: repoTimeZoneResolver())
        _ = flow.handleRecognized(items: sampleUSCardItems())
        flow.retake()
        XCTAssertEqual(flow.stage, .retaking)        // result cover is dismissing; camera not yet presented
        XCTAssertFalse(flow.isShowingResult)
        flow.resumeCameraAfterRetake()               // called from the cover's onDismiss
        XCTAssertEqual(flow.stage, .camera)
        flow.cancel()
        XCTAssertEqual(flow.stage, .idle)
        flow.resumeCameraAfterRetake()               // no-op outside of retaking
        XCTAssertEqual(flow.stage, .idle)
    }

    func testUpdateResultReplacesDraft() {
        let flow = ScanFlow(resolver: repoTimeZoneResolver())
        _ = flow.handleRecognized(items: sampleUSCardItems())
        var card = resultCard(flow)!
        card.name = "Edited"
        flow.updateResult(card)
        XCTAssertEqual(resultCard(flow)?.name.value, "Edited")
    }
}
