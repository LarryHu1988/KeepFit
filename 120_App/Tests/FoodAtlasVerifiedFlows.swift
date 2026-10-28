import XCTest

final class FoodAtlasVerifiedFlows: XCTestCase {
    func testSearchSelectUnitsAndSave() throws {
        let app = XCUIApplication(bundleIdentifier: "com.larry.keepfit")
        app.launchArguments = ["-keepfit-screenshot-mode", "-keepfit-selected-tab", "eat", "-keepfit-screenshot-date", "2026-10-26", "-keepfit-screenshot-focus", "eat-log"]
        app.launch()
        let selector = app.buttons["food.entry.selector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 15))
        if !selector.isHittable { app.swipeUp() }
        capture(app, "Food entry row")
        try choose(app, name: "水煮鸡蛋", id: "usda:173424")
        XCTAssertEqual(app.staticTexts["food.entry.unit"].label, "g")
        XCTAssertEqual(app.textFields["food.entry.amount"].value as? String, "100")
        app.buttons["food.entry.add"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "100g")).firstMatch.waitForExistence(timeout: 5))
        try choose(app, name: "图谱测试牛奶", id: "custom:qa-milk")
        XCTAssertEqual(app.staticTexts["food.entry.unit"].label, "mL")
        let amount = app.textFields["food.entry.amount"]
        amount.tap()
        amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "250")
        app.buttons["food.entry.add"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "250mL")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "Volume selected and saved")
        try choose(app, name: "图谱测试鸡蛋", id: "custom:qa-egg")
        XCTAssertEqual(app.staticTexts["food.entry.unit"].label, "个")
        XCTAssertEqual(app.textFields["food.entry.amount"].value as? String, "1")
        app.buttons["food.entry.add"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "1个")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "Count selected and saved")
        selector.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("zzzz-no-such-food-xyz")
        XCTAssertFalse(app.buttons["food.choice.usda:173424"].exists)
        capture(app, "Empty search results")
    }

    private func choose(_ app: XCUIApplication, name: String, id: String) throws {
        let selector = app.buttons["food.entry.selector"]
        if !selector.isHittable { app.swipeUp() }
        selector.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        search.tap(); search.typeText(name)
        let item = app.buttons["food.choice." + id]
        XCTAssertTrue(item.waitForExistence(timeout: 8))
        XCTAssertEqual(item.label, name, "A food row should expose only its name, without nutrition or reference subtitles.")
        capture(app, "Search " + name)
        item.tap()
        XCTAssertTrue(selector.waitForExistence(timeout: 5))
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
