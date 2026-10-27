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
        showHistory(in: app)
        QA.checkpoint(app, "history")
        for tab in ["Learn", "Settings"] {
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

    /// The core loop: start a mode, finish it, rate it, and find it in History,
    /// still there after a relaunch.
    func testCoreLoopPressSessionIsLoggedInHistory() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.queasy")
        // Debug-only automation flag: keeps the system rating prompt off the finished session.
        QA.launch(app, arguments: ["-FASTLANE_SNAPSHOT"])
        finishOnboardingIfShown(in: app)
        relieve("core-relieve", in: app)

        showHistory(in: app)
        let before = loggedPressCount(in: app)
        QA.checkpoint(app, "core-history-before")

        tapTab("Relieve", in: app)
        reveal(app.buttons["mode-card-press"].firstMatch, in: app).tap()
        let start = reveal(app.buttons["mode-start-phone"].firstMatch, in: app)
        QA.checkpoint(app, "core-press-mode")
        start.tap()

        let timer = app.staticTexts["session-timer"].firstMatch
        XCTAssertTrue(timer.waitForExistence(timeout: 15))
        QA.checkpoint(app, "core-press-running", ambient: ["session-timer"])
        XCTAssertLessThan(seconds(timer.label), pressSeconds, "the hold timer is not counting down")
        tap("end-session", in: app)

        let better = app.buttons["after-feeling-better"].firstMatch
        XCTAssertTrue(better.waitForExistence(timeout: 15))
        QA.checkpoint(app, "core-rating")
        better.tap()

        XCTAssertTrue(app.buttons["quick-start"].firstMatch.waitForExistence(timeout: 15))
        showHistory(in: app)
        assertNewestPressRow(count: before + 1, in: app)
        QA.checkpoint(app, "core-history-after")

        QA.relaunch(app)
        relieve("core-relieve-after-relaunch", in: app)
        showHistory(in: app)
        assertNewestPressRow(count: before + 1, in: app)
        QA.checkpoint(app, "core-history-after-relaunch")
    }

    /// Press is a fixed 3-minute hold, so its History row reads "3 min · iPhone".
    private let pressSeconds = 180
    private let pressDetail = NSPredicate(format: "label == %@", "3 min · iPhone")

    private func loggedPressCount(in app: XCUIApplication) -> Int {
        let list = app.buttons["Export history as CSV"].firstMatch
        if !list.waitForExistence(timeout: 5) {
            XCTAssertTrue(app.staticTexts["No sessions yet"].firstMatch.exists)
            return 0
        }
        return app.staticTexts.matching(pressDetail).count
    }

    /// The session just rated is the top row: Press, on this iPhone, and the
    /// "Better" rating (severity 3 to 1) as a drop of two.
    private func assertNewestPressRow(count: Int, in app: XCUIApplication,
                                      file: StaticString = #filePath, line: UInt = #line) {
        let detail = app.staticTexts.matching(pressDetail).firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 15), "the finished Press session is not in History",
                      file: file, line: line)
        XCTAssertEqual(app.staticTexts.matching(pressDetail).count, count, "History did not gain exactly one session",
                       file: file, line: line)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Press · ")).firstMatch.exists,
                      file: file, line: line)
        let row = detail.frame
        let badge = app.staticTexts.matching(NSPredicate(format: "label == %@", "\u{2212}2")).allElementsBoundByIndex
            .contains { $0.frame.midY < row.maxY && $0.frame.midY > row.minY - 3 * row.height }
        XCTAssertTrue(badge, "the newest row does not show the Better rating as \u{2212}2", file: file, line: line)
    }

    /// "2:57" as seconds.
    private func seconds(_ clock: String) -> Int {
        let parts = clock.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return Int.max }
        return parts[0] * 60 + parts[1]
    }

    /// A journey run on its own starts on a fresh install, before onboarding.
    private func finishOnboardingIfShown(in app: XCUIApplication) {
        guard !app.buttons["quick-start"].firstMatch.waitForExistence(timeout: 10) else { return }
        for _ in 0..<3 { tap("Continue", in: app) }
        let phoneOnly = app.buttons["onboarding-phone-only"]
        if phoneOnly.waitForExistence(timeout: 15) { phoneOnly.tap() } else { tap("Get Started", in: app) }
    }

    /// Scrolls the element's own pane until it can be tapped (AX3 pushes the
    /// mode grid and start button below the fold).
    @discardableResult
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: 15))
        var tries = 0
        while !element.isHittable && tries < 8 {
            let pane = app.scrollViews.containing(.button, identifier: element.identifier).allElementsBoundByIndex.last
            (pane ?? app).swipeUp()
            tries += 1
        }
        return element
    }

    /// Folded, History is a tab. Unfolded on a Duo, it is the pane after the fold.
    private func showHistory(in app: XCUIApplication) {
        let tab = app.tabBars.buttons["History"].firstMatch
        if tab.waitForExistence(timeout: 3) { tab.tap() }
    }

    private func tap(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
    }

    /// A tab-bar button folded; unfolded on a Duo, the same label in the pane's tab strip.
    private func tapTab(_ label: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[label].firstMatch
        let button = tab.waitForExistence(timeout: 3) ? tab : app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
    }

    private func checkpoint(_ name: String, button label: String, in app: XCUIApplication,
                            journey: String = #function) {
        XCTAssertTrue(app.buttons[label].firstMatch.waitForExistence(timeout: 15))
        QA.checkpoint(app, name, journey: journey)
    }

    /// The Relieve home, found by its quick start: the tab bar is hidden on an unfolded Duo.
    private func relieve(_ name: String, in app: XCUIApplication, journey: String = #function) {
        XCTAssertTrue(app.buttons["quick-start"].firstMatch.waitForExistence(timeout: 20))
        QA.checkpoint(app, name, journey: journey)
    }
}
