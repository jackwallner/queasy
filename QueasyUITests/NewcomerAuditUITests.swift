import XCTest

/// First-time-user walk for the newcomer persona audit. Not a regression gate:
/// every test captures screenshots and element frames as attachments, and only
/// asserts that the screen it reached exists.
final class NewcomerAuditUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = true
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.queasy")
        app.launchArguments += extra
        app.launch()
        return app
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func note(_ name: String, _ text: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func frameNote(_ label: String, _ element: XCUIElement) -> String {
        guard element.exists else { return "\(label): missing" }
        let f = element.frame
        return "\(label): \(Int(f.width))x\(Int(f.height)) at (\(Int(f.minX)),\(Int(f.minY))) hittable=\(element.isHittable)"
    }

    // MARK: - 1. First launch and onboarding

    func testOnboardingWalk() {
        let app = launch(["-QueasyResetOnboarding"])
        let next = app.buttons["onboarding-continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 20))
        sleep(1)
        shot("onb-1")
        var notes = [frameNote("continue", next)]
        for page in 2...4 {
            next.tap()
            sleep(1)
            shot("onb-\(page)")
            notes.append(frameNote("continue p\(page)", next))
        }
        let phoneOnly = app.buttons["onboarding-phone-only"]
        notes.append(frameNote("phone-only link", phoneOnly))
        note("onboarding-frames", notes.joined(separator: "\n"))
        // How many taps and swipes before the first useful screen.
        note("onboarding-taps", "Continue taps to reach gate: 3; then 1 more to enter the app")
        if phoneOnly.exists { phoneOnly.tap() } else { next.tap() }
        sleep(2)
        shot("home-first-run")
    }

    // MARK: - 2. Quick start: tap, session, rate, history

    func testQuickStartSession() {
        let app = launch()
        shot("fresh-launch")
        let quick = app.buttons["quick-start"]
        if !quick.waitForExistence(timeout: 15) {
            let skip = app.buttons["onboarding-phone-only"]
            let cont = app.buttons["onboarding-continue"]
            while !skip.exists, cont.exists { cont.tap(); sleep(1) }
            if skip.exists { skip.tap() } else if cont.exists { cont.tap() }
        }
        XCTAssertTrue(quick.waitForExistence(timeout: 15))
        sleep(1)
        shot("home-top")
        note("home-frames", [
            frameNote("quick-start", quick),
            frameNote("mode-pulse", app.buttons["mode-card-pulse"]),
            frameNote("checkin", app.buttons["start-checkin"]),
        ].joined(separator: "\n"))
        app.swipeUp()
        sleep(1)
        shot("home-scrolled")
        app.swipeDown()

        quick.tap()
        let done = app.buttons["end-session"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        sleep(2)
        shot("session-running")
        let cancel = app.buttons["Cancel session"]
        note("session-frames", [
            frameNote("cancel X", cancel),
            frameNote("I'm Done", done),
            frameNote("minus", app.buttons["Decrease intensity"]),
            frameNote("plus", app.buttons["Increase intensity"]),
        ].joined(separator: "\n"))

        done.tap()
        let better = app.buttons["after-feeling-better"]
        XCTAssertTrue(better.waitForExistence(timeout: 5))
        shot("session-rating")
        better.tap()
        sleep(2)
        shot("home-after-session")

        app.tabBars.buttons["History"].tap()
        sleep(1)
        shot("history-after-first")
    }

    // MARK: - 3. Check-in, including swiping past unanswered questions

    func testCheckInFlow() {
        let app = launch()
        let start = app.buttons["start-checkin"]
        if !start.waitForExistence(timeout: 15) {
            let cont = app.buttons["onboarding-continue"]
            let skip = app.buttons["onboarding-phone-only"]
            while !skip.exists, cont.exists { cont.tap(); sleep(1) }
            if skip.exists { skip.tap() }
        }
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        start.tap()
        sleep(1)
        shot("checkin-1-cause")

        // Swipe forward without answering anything.
        app.swipeLeft(); sleep(1)
        shot("checkin-swipe-1")
        app.swipeLeft(); sleep(1)
        shot("checkin-swipe-2")
        app.swipeLeft(); sleep(1)
        shot("checkin-swipe-3-unanswered")

        // Back to the start, answer properly.
        for _ in 0..<3 { app.swipeRight(); sleep(1) }
        app.buttons["cause-motion"].tap()
        sleep(1)
        shot("checkin-2-severity")
        // Is there any visible way to go back?
        note("checkin-back", "Navigation buttons: " + app.navigationBars.buttons.allElementsBoundByIndex.map { $0.label }.joined(separator: ", "))
        app.buttons["severity-3"].tap()
        sleep(1)
        shot("checkin-3-context")
        app.buttons["exposed-yes"].tap()
        app.buttons["ate-no"].tap()
        sleep(2)
        shot("checkin-4-recommend")
        app.swipeUp()
        sleep(1)
        shot("checkin-4-recommend-scrolled")
    }

    // MARK: - 4. Mode cards

    func testModeDetails() {
        let app = launch()
        let card = app.buttons["mode-card-pulse"]
        if !card.waitForExistence(timeout: 15) {
            let cont = app.buttons["onboarding-continue"]
            let skip = app.buttons["onboarding-phone-only"]
            while !skip.exists, cont.exists { cont.tap(); sleep(1) }
            if skip.exists { skip.tap() }
        }
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        for mode in ["pulse", "breathe", "tone", "press"] {
            app.buttons["mode-card-\(mode)"].tap()
            sleep(2)
            shot("mode-\(mode)")
            if mode == "press" {
                app.swipeUp(); sleep(1)
                shot("mode-press-scrolled")
            }
            app.buttons["Close"].firstMatch.tap()
            sleep(1)
        }
    }

    // MARK: - 5. Learn, Settings, paywall

    func testLearnSettingsPaywall() {
        let app = launch()
        let tabs = app.tabBars.buttons["Learn"]
        if !tabs.waitForExistence(timeout: 15) {
            let cont = app.buttons["onboarding-continue"]
            let skip = app.buttons["onboarding-phone-only"]
            while !skip.exists, cont.exists { cont.tap(); sleep(1) }
            if skip.exists { skip.tap() }
        }
        XCTAssertTrue(tabs.waitForExistence(timeout: 15))
        tabs.tap(); sleep(1)
        shot("learn")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Pulse, and what'")).firstMatch.tap()
        sleep(1)
        shot("learn-pulse-open")

        app.tabBars.buttons["History"].tap(); sleep(1)
        shot("history-empty")

        app.tabBars.buttons["Settings"].tap(); sleep(1)
        shot("settings")
        app.swipeUp(); sleep(1)
        shot("settings-scrolled")
        app.swipeDown()
        let pro = app.buttons["settings-see-pro"]
        if pro.exists {
            pro.tap()
            sleep(4)
            shot("paywall")
            app.swipeUp(); sleep(1)
            shot("paywall-scrolled")
        }
    }

    // MARK: - 6. Settings load time (main-thread stall seen in the first run)

    func testSettingsTimed() {
        let app = launch()
        let tabs = app.tabBars.buttons["Settings"]
        if !tabs.waitForExistence(timeout: 15) {
            let cont = app.buttons["onboarding-continue"]
            let skip = app.buttons["onboarding-phone-only"]
            while !skip.exists, cont.exists { cont.tap(); sleep(1) }
            if skip.exists { skip.tap() }
        }
        XCTAssertTrue(tabs.waitForExistence(timeout: 15))
        let start = Date()
        tabs.tap()
        let toggle = app.switches["press-reminders"]
        let appeared = toggle.waitForExistence(timeout: 60)
        let elapsed = Date().timeIntervalSince(start)
        note("settings-load", "Settings content visible=\(appeared) after \(String(format: "%.1f", elapsed))s")
        shot("settings-loaded")
        if appeared {
            app.swipeUp(); sleep(1)
            shot("settings-scrolled")
            app.swipeDown()
            let pro = app.buttons["settings-see-pro"]
            if pro.exists {
                pro.tap(); sleep(4)
                shot("paywall")
                app.swipeUp(); sleep(1)
                shot("paywall-scrolled")
            }
        }
    }
}
