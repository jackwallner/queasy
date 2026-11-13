import XCTest

/// iPad captures. Nothing but XCTest can rotate a headless iPad, so landscape
/// frames come from here: each job launches the app with debug arguments, turns
/// the device and attaches the screen. Runs only on an iPad.
final class IPadCaptureUITests: XCTestCase {
    private let base = ["-QueasyScreenshots", "-QueasyProOverride", "-QueasySeedDemoData"]
    private let onboarding = ["-QueasyResetOnboarding"]

    private var jobs: [(String, [String])] {
        [
            ("relieve", base + ["-QueasyTab", "relieve"]),
            ("history", base + ["-QueasyTab", "history"]),
            ("learn", base + ["-QueasyTab", "learn"]),
            ("settings", base + ["-QueasyTab", "settings"]),
            ("press", base + ["-QueasyScreen", "mode-press"]),
            ("session", base + ["-QueasyScreen", "session-breathe"]),
            ("checkin", base + ["-QueasyScreen", "checkin"]),
            ("upgrade", base + ["-QueasyScreen", "upgrade"]),
            ("onboarding0", onboarding + ["-QueasyOnboardingPage", "0"]),
            ("onboarding1", onboarding + ["-QueasyOnboardingPage", "1"]),
        ]
    }

    func testCapture() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad only") }
        let env = ProcessInfo.processInfo.environment
        let only = env["IPAD_ONLY"]?.split(separator: ",").map(String.init)
        let orientations = (env["IPAD_ORIENTATIONS"] ?? "landscape,portrait").split(separator: ",").map(String.init)
        continueAfterFailure = true
        for orientation in orientations {
            for (name, args) in jobs where only == nil || only!.contains(name) {
                XCUIDevice.shared.orientation = orientation == "landscape" ? .landscapeRight : .portrait
                let app = XCUIApplication(bundleIdentifier: "com.jackwallner.queasy")
                app.terminate()
                app.launchArguments = args
                app.launch()
                sleep(6)
                XCUIDevice.shared.orientation = orientation == "landscape" ? .landscapeRight : .portrait
                sleep(3)
                let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                attachment.name = "\(name)-\(orientation)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        XCUIDevice.shared.orientation = .portrait
    }

    /// The six App Store frames, portrait, once per store locale. Each attachment
    /// is `<locale>-<frame>`; `scripts/build-ipad-screenshots.py` frames them.
    func testStoreFrames() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad only") }
        let locales = [("en-US", "en", "en_US"), ("ja", "ja", "ja_JP"), ("id", "id", "id_ID"), ("nl-NL", "nl", "nl_NL")]
        let frames: [(String, [String])] = [
            ("1-home", base + ["-QueasyTab", "relieve"]),
            ("2-breathe", base + ["-QueasyScreen", "session-breathe"]),
            ("3-press", base + ["-QueasyScreen", "mode-press"]),
            ("4-recommend", base + ["-QueasyScreen", "recommend-motion"]),
            ("5-learn", base + ["-QueasyTab", "learn"]),
            ("6-history", base + ["-QueasyTab", "history"]),
        ]
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        for (store, language, region) in locales {
            for (name, args) in frames {
                let app = XCUIApplication(bundleIdentifier: "com.jackwallner.queasy")
                app.terminate()
                app.launchArguments = args + ["-AppleLanguages", "(\(language))", "-AppleLocale", region]
                app.launch()
                sleep(7)
                let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                attachment.name = "\(store)-\(name)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }
}
