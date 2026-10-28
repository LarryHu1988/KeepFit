import XCTest

final class SettingsVerifiedFlows: XCTestCase {
    private func launchSettings() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.larry.keepfit")
        app.launchArguments = ["-keepfit-screenshot-mode", "-keepfit-screenshot-root", "settings", "-keepfit-screenshot-focus", "settings-other"]
        app.launch()
        XCTAssertTrue(app.buttons["分享 APP"].waitForExistence(timeout: 10))
        return app
    }

    func testRelatedAppsAndAbout() throws {
        let app = launchSettings()
        app.buttons["更多 APP"].tap()
        XCTAssertTrue(app.staticTexts["PDF Librarian"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Mac / macOS 13+"].exists)
        XCTAssertTrue(app.staticTexts["简值 · SimpleWorth"].exists)
        for icon in ["SimpleWorthBrandIcon", "PDFLibrarianBrandIcon"] {
            XCTAssertTrue(app.descendants(matching: .any)[icon + "-store"].exists)
            XCTAssertTrue(app.descendants(matching: .any)[icon + "-home"].exists)
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "More Apps"; shot.lifetime = .keepAlways; add(shot)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["关于KeepFit"].tap()
        XCTAssertTrue(app.staticTexts["Larry Hu"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["keepfit@larryhu.com"].exists)
        let about = XCTAttachment(screenshot: app.screenshot())
        about.name = "About KeepFit"; about.lifetime = .keepAlways; add(about)
    }

    func testNativeShareSheetOnFirstTap() throws {
        let app = launchSettings()
        app.buttons["分享 APP"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.cells["Copy"].exists || app.cells["拷贝"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Native Share Sheet"; shot.lifetime = .keepAlways; add(shot)
    }
}
