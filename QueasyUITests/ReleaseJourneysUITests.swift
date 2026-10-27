import XCTest

@MainActor
final class ReleaseJourneysUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func test1OnboardingToRelieve() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.queasy")
        QA.launch(app, arguments: ["-QueasyResetOnboarding"])
        for name in ["four-things", "three-questions", "watch-wrist"] {
            checkpoint(name, button: "Continue", in: app)
            tap("Continue", in: app)
        }
        let phoneOnly = app.buttons["onboarding-phone-only"]
        let ready = app.buttons["Get Started"]
        XCTAssertTrue(phoneOnly.waitForExistence(timeout: 15) || ready.exists)
        QA.checkpoint(app, "watch-gate")
        if phoneOnly.exists { phoneOnly.tap() } else { ready.tap() }
        relieve("first-relieve", in: app)
    }

    func test2TabsUpgradeAndReturn() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.queasy")
        QA.launch(app, arguments: ["-QueasySeedDemoData"])
        relieve("relieve", in: app)
        for tab in ["History", "Learn", "Settings"] {
            tapTab(tab, in: app)
            QA.checkpoint(app, tab.lowercased())
        }
        let pro = app.buttons["See Queasy Pro"].firstMatch
        var tries = 0
        while !(pro.exists && pro.isHittable) && tries < 8 {
            app.swipeUp()
            tries += 1
        }
        pro.tap()
        XCTAssertTrue(app.buttons["Restore Purchases"].waitForExistence(timeout: 20))
        QA.checkpoint(app, "upgrade", paywall: true)
        tap("Close", in: app)
        tapTab("Relieve", in: app)
        relieve("relieve-after-upgrade", in: app)
        QA.interrupt(app)
        relieve("relieve-after-background", in: app)
        QA.relaunch(app)
        relieve("relieve-after-relaunch", in: app)
    }

    private func tap(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
    }

    private func tapTab(_ label: String, in app: XCUIApplication) {
        let button = app.tabBars.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
    }

    private func checkpoint(_ name: String, button label: String, in app: XCUIApplication) {
        XCTAssertTrue(app.buttons[label].firstMatch.waitForExistence(timeout: 15))
        QA.checkpoint(app, name)
    }

    private func relieve(_ name: String, in app: XCUIApplication) {
        XCTAssertTrue(app.tabBars.buttons["Relieve"].firstMatch.waitForExistence(timeout: 20))
        QA.checkpoint(app, name)
    }
}
