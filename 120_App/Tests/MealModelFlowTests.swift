import XCTest

final class MealModelFlowTests: XCTestCase {
    func testTextClarificationAndConfirmationReturnsToApp() throws {
        let app = XCUIApplication(bundleIdentifier: "com.larry.keepfit")
        app.launchArguments = ["-keepfit-screenshot-mode", "-keepfit-screenshot-date", "2026-10-23", "-keepfit.appLanguage", "chinese"]
        app.launchEnvironment["KEEPFIT_MODEL_URL"] = "http://127.0.0.1:18766/"
        app.launchEnvironment["KEEPFIT_MODEL_TEST_TOKEN"] = "keepfit-isolated-simulator-flow-test-token"
        app.launch()
        let entry = app.buttons["meal.entry.text"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15), app.debugDescription)
        if !entry.isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["meal.entry.voice"].exists)
        XCTAssertTrue(app.buttons["meal.entry.photo"].exists)
        entry.tap()
        let restart = app.buttons["重新记录另一餐"]
        if restart.waitForExistence(timeout: 2) { app.swipeUp(); restart.tap() }
        let input = app.textFields["meal.text"]
        XCTAssertTrue(input.waitForExistence(timeout: 10), app.debugDescription)
        input.tap(); input.typeText("早餐两个鸡蛋、一杯牛奶")
        app.swipeUp()
        let consent = app.switches["meal.consent"]
        XCTAssertTrue(consent.exists, app.debugDescription)
        consent.tap()
        let recognize = app.buttons["meal.recognize"]
        if !recognize.isHittable { app.swipeUp() }
        recognize.tap()
        XCTAssertTrue(app.staticTexts["这杯牛奶大约多大？"].waitForExistence(timeout: 15), app.debugDescription)
        app.swipeUp()
        let cup = app.buttons["普通杯（250ml）"]
        if !cup.isHittable { app.swipeUp() }
        cup.tap()
        let update = app.buttons["用这些补充更新"]
        if !update.isHittable { app.swipeUp() }
        update.tap()
        XCTAssertTrue(app.staticTexts["meal.total"].waitForExistence(timeout: 15), app.debugDescription)
        app.swipeUp()
        let accept = app.switches["meal.accept"]
        if !accept.isHittable { app.swipeUp() }
        accept.tap()
        let confirm = app.buttons["meal.confirm"]
        if !confirm.isHittable { app.swipeUp() }
        XCTAssertTrue(confirm.isEnabled)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Meal ready for confirmation"; shot.lifetime = .keepAlways; add(shot)
        confirm.tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 15), app.debugDescription)
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["meal.confirm"])
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 15), .completed, app.debugDescription)
        let saved = XCTAttachment(screenshot: app.screenshot()); saved.name = "Meal saved in KeepFit"; saved.lifetime = .keepAlways; add(saved)
    }
}
