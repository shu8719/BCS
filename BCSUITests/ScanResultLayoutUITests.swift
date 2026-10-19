import XCTest

/// Drives the scan result screen on a simulator and checks that its top bar never moves under the
/// status bar, including after the "enter the missing company" edit the review banner asks for.
final class ScanResultLayoutUITests: XCTestCase {
    private var shotDirectory: URL? {
        ProcessInfo.processInfo.environment["BCS_SHOT_DIR"].map { URL(fileURLWithPath: $0) }
    }

    private func snapshot(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = shotDirectory {
            try? shot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
        }
    }

    /// User report: scan a good card, save it, then scan a card whose company cannot be read —
    /// the second result screen slides under the status bar.
    func testSecondCameraScanAfterSavingKeepsTopBarBelowStatusBar() throws {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments = ["-fakeDocumentCamera", "-uiTestTemporaryStore",
                               "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        let title = app.staticTexts["読み取り結果"]

        func scanWithCamera(_ name: String) -> CGFloat {
            XCTAssertTrue(app.buttons["scanFAB"].waitForExistence(timeout: 10))
            app.buttons["scanFAB"].tap()
            XCTAssertTrue(app.buttons["scanMenuCamera"].waitForExistence(timeout: 5))
            app.buttons["scanMenuCamera"].tap()
            let shutter = app.buttons["fakeShutter"]
            XCTAssertTrue(shutter.waitForExistence(timeout: 10))
            shutter.tap()
            XCTAssertTrue(title.waitForExistence(timeout: 20))
            sleep(2)
            snapshot(name)
            let y = title.frame.minY
            print("LAYOUT \(name) titleY=\(y)")
            return y
        }

        let first = scanWithCamera("cam_1_first")
        let save = app.buttons.matching(NSPredicate(format: "label CONTAINS '保存する'")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 10))
        sleep(1)
        snapshot("cam_2_list_after_save")

        let second = scanWithCamera("cam_3_second")
        XCTAssertGreaterThan(first, 50, "first result: top bar is under the status bar")
        XCTAssertEqual(second, first, accuracy: 1, "second result: top bar moved")
        XCTAssertGreaterThan(second, 50, "second result: top bar is under the status bar")
    }

    /// Same report via 写真から選ぶ: load one card, save it, then load another.
    /// Needs at least two photos taken this year in the simulator's library, e.g. the cards in `sample/`
    /// (`xcrun simctl addmedia booted sample/tarou_yamada_card.png sample/hanako_sato_card.png`).
    func testSecondPhotoScanAfterSavingKeepsTopBarBelowStatusBar() throws {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestTemporaryStore", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        let title = app.staticTexts["読み取り結果"]

        func pickPhoto(_ index: Int, _ name: String) -> CGFloat {
            XCTAssertTrue(app.buttons["scanFAB"].waitForExistence(timeout: 10))
            app.buttons["scanFAB"].tap()
            XCTAssertTrue(app.buttons["scanMenuPhoto"].waitForExistence(timeout: 5))
            app.buttons["scanMenuPhoto"].tap()
            let photos = app.images.matching(NSPredicate(format: "label BEGINSWITH '写真' AND NOT (label CONTAINS '年')"))
            if !photos.firstMatch.waitForExistence(timeout: 10) {
                XCTFail("sample cards missing: add them with `xcrun simctl addmedia booted <png>`")
            }
            sleep(2)   // let the picker finish presenting
            photos.element(boundBy: index).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(title.waitForExistence(timeout: 20))
            sleep(2)
            snapshot(name)
            let y = title.frame.minY
            print("LAYOUT \(name) titleY=\(y)")
            return y
        }

        let first = pickPhoto(0, "photo_1_first")
        let save = app.buttons.matching(NSPredicate(format: "label CONTAINS '保存する'")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 10))
        sleep(1)

        let second = pickPhoto(1, "photo_2_second")
        XCTAssertGreaterThan(first, 50, "first result: top bar is under the status bar")
        XCTAssertEqual(second, first, accuracy: 1, "second result: top bar moved")
        XCTAssertGreaterThan(second, 50, "second result: top bar is under the status bar")
    }

    func testTopBarStaysBelowStatusBarWhileEditingMissingCompany() throws {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments = ["-showScanResultMissingCompany", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()

        let title = app.staticTexts["読み取り結果"]
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        sleep(1)
        let initialY = title.frame.minY
        snapshot("1_opened")
        print("LAYOUT opened titleY=\(initialY)")

        let companyRow = app.staticTexts["会社 ・ 要確認"]
        XCTAssertTrue(companyRow.waitForExistence(timeout: 5))
        companyRow.tap()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        sleep(1)
        snapshot("2_editing")
        print("LAYOUT editing titleY=\(title.exists ? title.frame.minY : -1) keyboard=\(app.keyboards.count)")

        field.typeText("Northwind")
        app.buttons["保存"].firstMatch.tap()
        sleep(2)
        snapshot("3_after_save")
        let afterY = title.frame.minY
        print("LAYOUT after_save titleY=\(afterY)")

        XCTAssertEqual(afterY, initialY, accuracy: 1, "top bar moved after editing a field")
        XCTAssertGreaterThan(afterY, 50, "top bar is under the status bar")
    }
}
