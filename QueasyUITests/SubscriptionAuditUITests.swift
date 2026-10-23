import XCTest

/// Skeptical-free-user walk for the subscription persona audit: what is paid,
/// what the paywall promises, restore, and the cancel/exit paths. Not a
/// regression gate: it captures screenshots and element facts as attachments.
/// No purchase is ever attempted and no RevenueCat key is configured.
final class SubscriptionAuditUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = true
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.queasy")
        app.launchArguments += extra
        app.launch()
        let tabs = app.tabBars.buttons["Settings"]
        if !tabs.waitForExistence(timeout: 15) {
            let cont = app.buttons["onboarding-continue"]
            let skip = app.buttons["onboarding-phone-only"]
            while !skip.exists, cont.exists { cont.tap(); sleep(1) }
            if skip.exists { skip.tap() }
        }
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

    private func allLabels(_ app: XCUIApplication) -> String {
        let buttons = app.buttons.allElementsBoundByIndex.map { "button: \($0.label)" }
        let texts = app.staticTexts.allElementsBoundByIndex.map { "text: \($0.label)" }
        return (buttons + texts).joined(separator: "\n")
    }

    // MARK: - 1. Free user opens the paywall from Settings, tries restore

    func testFreePaywallAndRestore() {
        let app = launch()
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["press-reminders"].waitForExistence(timeout: 60))
        sleep(1)
        shot("settings-free-top")
        app.swipeUp(); sleep(1)
        shot("settings-free-scrolled")
        note("settings-free-labels", allLabels(app))
        app.swipeDown()

        // Settings restore, with nothing to restore.
        let restore = app.buttons["Restore Purchases"]
        note("settings-restore-frame", frameNote("restore", restore))
        if restore.exists {
            restore.tap()
            sleep(1); shot("settings-restore-after-1s")
            sleep(4); shot("settings-restore-after-5s")
        }

        let pro = app.buttons["settings-see-pro"]
        XCTAssertTrue(pro.waitForExistence(timeout: 5))
        pro.tap()
        sleep(4)
        shot("paywall-free")
        note("paywall-free-labels", allLabels(app))
        let close = app.buttons["Close"]
        let paywallRestore = app.buttons["Restore Purchases"]
        let tryAgain = app.buttons["try again"]
        note("paywall-frames", [
            frameNote("close", close),
            frameNote("restore", paywallRestore),
            frameNote("try again", tryAgain),
            frameNote("terms", app.links["Terms of Use"]),
            frameNote("privacy", app.links["Privacy Policy"]),
        ].joined(separator: "\n"))
        if tryAgain.exists {
            tryAgain.tap(); sleep(2)
            shot("paywall-try-again")
        }
        if paywallRestore.exists {
            paywallRestore.tap()
            sleep(1); shot("paywall-restore-1s")
            sleep(4); shot("paywall-restore-5s")
        }
        if close.exists {
            close.tap(); sleep(1)
            shot("after-paywall-close")
        }
    }

    // MARK: - 2. What is actually gated

    func testFreeBoundary() {
        let app = launch()
        let quick = app.buttons["quick-start"]
        XCTAssertTrue(quick.waitForExistence(timeout: 15))
        // Quick start: how long does a free session run?
        quick.tap()
        XCTAssertTrue(app.buttons["end-session"].waitForExistence(timeout: 10))
        sleep(2)
        shot("quick-session-free")
        note("quick-session-labels", allLabels(app))
        app.buttons["end-session"].tap()
        let better = app.buttons["after-feeling-better"]
        if better.waitForExistence(timeout: 5) { better.tap() }
        sleep(2)

        // Mode card with the length note.
        let card = app.buttons["mode-card-breathe"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap(); sleep(2)
        shot("mode-breathe-free")
        let unlock = app.buttons["mode-unlock-length"]
        note("mode-unlock-frame", frameNote("unlock note", unlock))
        if unlock.exists {
            unlock.tap(); sleep(4)
            shot("paywall-from-mode")
            app.buttons["Close"].tap(); sleep(1)
        }
        app.buttons["Close"].firstMatch.tap(); sleep(1)

        // Settings: pickers the paywall lists as Pro ("Pick your own rhythm and level").
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["press-reminders"].waitForExistence(timeout: 60))
        let rhythm = app.buttons["Breathing rhythm"]
        note("rhythm-picker", frameNote("breathing rhythm picker", rhythm))
        if rhythm.exists {
            rhythm.tap(); sleep(1)
            shot("settings-rhythm-picker-free")
            note("rhythm-options", allLabels(app))
            if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
            sleep(1)
        }
        // Press reminders toggle for a free user.
        app.switches["press-reminders"].tap(); sleep(3)
        shot("settings-press-reminders-tap")
        note("press-tap-labels", allLabels(app))
    }

    // MARK: - 3. History gate

    func testHistoryGate() {
        let app = launch(["-QueasySeedDemoData"])
        app.tabBars.buttons["History"].tap(); sleep(2)
        shot("history-free-seeded")
        let unlock = app.buttons["history-unlock"]
        if !unlock.exists { app.swipeUp(); sleep(1) }
        shot("history-free-seeded-scrolled")
        note("history-unlock-frame", frameNote("older sessions row", unlock))
        note("history-labels", allLabels(app))
        if unlock.exists {
            unlock.tap(); sleep(4)
            shot("paywall-from-history")
        }
    }

    // MARK: - 4. Subscriber view: where is manage/cancel

    func testProSettingsExitPath() {
        let app = launch(["-QueasyProOverride"])
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["press-reminders"].waitForExistence(timeout: 60))
        sleep(1)
        shot("settings-pro-top")
        app.swipeUp(); sleep(1)
        shot("settings-pro-scrolled")
        let labels = allLabels(app)
        note("settings-pro-labels", labels)
        let manage = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'manage' OR label CONTAINS[c] 'cancel' OR label CONTAINS[c] 'subscription'")).count
        note("settings-pro-manage-rows", "Rows mentioning manage/cancel/subscription: \(manage)")
        app.swipeDown(); sleep(1)
        let restore = app.buttons["Restore Purchases"]
        if restore.exists { restore.tap(); sleep(3); shot("settings-pro-restore") }
    }

    // MARK: - 5. Static paywall (what a store reviewer sees)

    func testMockPaywall() {
        let app = XCUIApplication(bundleIdentifier: "com.jackwallner.queasy")
        app.launchArguments += ["-QueasyPaywallScreenshot"]
        app.launch()
        sleep(5)
        shot("paywall-mock")
        app.swipeUp(); sleep(1)
        shot("paywall-mock-scrolled")
        note("paywall-mock-labels", allLabels(app))
    }
}
