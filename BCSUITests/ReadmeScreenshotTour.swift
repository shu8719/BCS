import XCTest

/// Captures the README screen images (docs/screens) on a simulator.
///
/// Skipped unless `BCS_SHOT_DIR` is set, so it never runs as part of Cmd+U. To regenerate:
/// 1. add the sample cards to the simulator: `xcrun simctl addmedia <device> sample/tarou_yamada_card.png sample/hanako_sato_card.png`
/// 2. optionally `xcrun simctl status_bar <device> override --time "$(date +%H:%M)" --batteryState charged --batteryLevel 100`
///    (keep the real time so it agrees with the local times shown on the cards)
/// 3. `TEST_RUNNER_BCS_SHOT_DIR=<dir> xcodebuild test -scheme BCS -destination 'id=<device>' -only-testing:BCSUITests/ReadmeScreenshotTour`
final class ReadmeScreenshotTour: XCTestCase {
    private var shotDirectory: URL?

    override func setUpWithError() throws {
        guard let dir = ProcessInfo.processInfo.environment["BCS_SHOT_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_BCS_SHOT_DIR to capture the README screenshots.")
        }
        shotDirectory = URL(fileURLWithPath: dir)
    }

    private func snapshot(_ name: String) {
        sleep(1)   // let animations settle
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = shotDirectory {
            try? shot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
        }
    }

    func testCaptureReadmeScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestTemporaryStore", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        let resultTitle = app.staticTexts["読み取り結果"]

        func scanPhoto(_ index: Int) {
            XCTAssertTrue(app.buttons["scanFAB"].waitForExistence(timeout: 10))
            app.buttons["scanFAB"].tap()
            XCTAssertTrue(app.buttons["scanMenuPhoto"].waitForExistence(timeout: 5))
            app.buttons["scanMenuPhoto"].tap()
            let photos = app.images.matching(NSPredicate(format: "label BEGINSWITH '写真' AND NOT (label CONTAINS '年')"))
            XCTAssertTrue(photos.firstMatch.waitForExistence(timeout: 10), "add the sample cards with simctl addmedia")
            sleep(2)
            photos.element(boundBy: index).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(resultTitle.waitForExistence(timeout: 20))
        }

        func saveResult() {
            app.buttons.matching(NSPredicate(format: "label CONTAINS '保存する'")).firstMatch.tap()
            XCTAssertTrue(resultTitle.waitForNonExistence(timeout: 10))
        }

        // 06: scan result (second card is captured before saving)
        scanPhoto(0)
        saveResult()
        scanPhoto(1)
        snapshot("06_scan_result")
        saveResult()

        // 01: list with both cards
        snapshot("01_list")

        // 01b: FAB menu open
        app.buttons["scanFAB"].tap()
        snapshot("01b_scan_menu")
        app.buttons["scanFAB"].tap()
        XCTAssertTrue(app.buttons["scanMenuCamera"].waitForNonExistence(timeout: 5))
        sleep(1)   // the scrim fades out after the items

        // 02: selection mode with one card selected
        app.buttons["icon-checklist"].tap()
        let selectionTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '件を選択中'")).firstMatch
        XCTAssertTrue(selectionTitle.waitForExistence(timeout: 5))
        app.staticTexts["Tarou Yamada"].tap()
        snapshot("02_select")
        app.buttons["icon-close"].firstMatch.tap()
        XCTAssertTrue(selectionTitle.waitForNonExistence(timeout: 5))

        // 03: detail
        XCTAssertTrue(app.staticTexts["Tarou Yamada"].waitForExistence(timeout: 5))
        app.staticTexts["Tarou Yamada"].tap()
        XCTAssertTrue(app.buttons["icon-edit"].waitForExistence(timeout: 5))
        snapshot("03_detail")

        // 04: edit sheet
        app.buttons["icon-edit"].tap()
        XCTAssertTrue(app.staticTexts["名刺を編集"].waitForExistence(timeout: 5))
        snapshot("04_edit")
        app.buttons["icon-close"].firstMatch.tap()

        // 07: settings
        XCTAssertTrue(app.buttons["icon-arrow-back"].waitForExistence(timeout: 5))
        app.buttons["icon-arrow-back"].tap()
        app.buttons["設定"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["表示"].waitForExistence(timeout: 5))
        snapshot("07_settings")
    }
}
