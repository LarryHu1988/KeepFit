import XCTest

final class ExerciseSelectionVerifiedFlows: XCTestCase {
    func testNameOnlyRowsSearchAndSave() throws {
        let app = XCUIApplication(bundleIdentifier: "com.larry.keepfit")
        app.launchArguments = ["-keepfit-screenshot-mode", "-keepfit-selected-tab", "move", "-keepfit-screenshot-date", "2026-10-27", "-keepfit-screenshot-focus", "move-log"]
        app.launch()
        let selector = app.buttons["exercise.entry.selector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 15))
        if !selector.isHittable { app.swipeUp() }
        selector.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertTrue(search.isHittable, "Search must be visible as soon as the picker opens.")
        let walking = app.buttons["exercise.choice.walking_slow"]
        XCTAssertTrue(walking.waitForExistence(timeout: 5))
        XCTAssertEqual(walking.label, "散步", "Rows must not expose MET or other subtitles.")
        capture(app, "Exercise names only and visible search")

        search.tap(); search.typeText("跑")
        let running = app.buttons["exercise.choice.running"]
        let jogging = app.buttons["exercise.choice.jogging"]
        XCTAssertTrue(running.waitForExistence(timeout: 5))
        XCTAssertTrue(jogging.exists)
        XCTAssertEqual(running.label, "跑步")
        XCTAssertEqual(jogging.label, "慢跑")
        capture(app, "Chinese exercise search")

        search.typeText(XCUIKeyboardKey.delete.rawValue + "  rUnNiNg  ")
        XCTAssertTrue(running.waitForExistence(timeout: 5))
        XCTAssertFalse(jogging.exists)
        capture(app, "English exercise search with surrounding spaces")
        running.tap()
        XCTAssertTrue(selector.waitForExistence(timeout: 5))
        XCTAssertTrue(selector.label.contains("跑步"))
        app.buttons["exercise.entry.add"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "30 min")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "Selected exercise saved")

        selector.tap()
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("zzzz-no-such-exercise-xyz")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "exercise.choice.")).count, 0)
        capture(app, "Empty exercise search results")
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "zzzz-no-such-exercise-xyz".count))
        XCTAssertTrue(walking.waitForExistence(timeout: 5))
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
