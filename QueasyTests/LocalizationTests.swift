import Foundation
import Testing

@testable import Queasy

/// The string catalog compiles into en.lproj, and its plural and substitution
/// values keep the English wording. A key that fell through would still pass a
/// "not empty" check, so these compare against the visible copy.
@Suite("Localization")
struct LocalizationTests {
    private func enBundle() throws -> Bundle {
        for host in [Bundle.main] + Bundle.allBundles {
            if let path = host.path(forResource: "en", ofType: "lproj"),
               FileManager.default.fileExists(atPath: path + "/Localizable.strings"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return try #require(nil as Bundle?, "en.lproj/Localizable.strings is missing")
    }

    @Test func pluralsKeepEnglishWording() throws {
        let en = try enBundle()
        #expect(String(localized: "\(1) older sessions", bundle: en) == "1 older session")
        #expect(String(localized: "\(4) older sessions", bundle: en) == "4 older sessions")
        #expect(String(localized: "\(10) minutes", bundle: en) == "10 minutes")
        #expect(String(localized: "\(2) minutes on the free plan", bundle: en) == "2 minutes on the free plan")
        #expect(String(localized: "\(3) minutes, timed for you", bundle: en) == "3 minutes, timed for you")
        #expect(String(localized: "\(18) min", bundle: en) == "18 min")
        #expect(String(localized: "\(3) min hold", bundle: en) == "3 min hold")
        #expect(String(localized: "\(7)-Day Free Trial", bundle: en) == "7-Day Free Trial")
    }

    /// These counts had no singular wording before the catalog, so English still has none.
    @Test func countsWithOneWordingStayAsTheyWere() throws {
        let en = try enBundle()
        #expect(String(localized: "Last \(1) days", bundle: en) == "Last 1 days")
        #expect(String(localized: "Last \(90) days", bundle: en) == "Last 90 days")
    }

    @Test func substitutionsKeepEnglishWording() throws {
        let en = try enBundle()
        #expect(String(localized: "Pulse and Breathe run up to \(45) minutes instead of \(2)-minute sessions, and keep going on your wrist with the screen off.", bundle: en)
            == "Pulse and Breathe run up to 45 minutes instead of 2-minute sessions, and keep going on your wrist with the screen off.")
        #expect(String(localized: "Every session kept, not just the last \(7) days, with which mode you tend to come out of feeling better.", bundle: en)
            == "Every session kept, not just the last 7 days, with which mode you tend to come out of feeling better.")
        #expect(String(localized: "Free sessions run \(2) minutes. Pro goes up to \(45).", bundle: en)
            == "Free sessions run 2 minutes. Pro goes up to 45.")
        #expect(String(localized: "Free sessions run \(2) minutes. Pro runs the full \(15).", bundle: en)
            == "Free sessions run 2 minutes. Pro runs the full 15.")
        #expect(String(localized: "\("4 in · 6 out") · about \(6) breaths a minute", bundle: en)
            == "4 in · 6 out · about 6 breaths a minute")
        #expect(String(localized: "Level \(5) · \(15) min on your wrist", bundle: en) == "Level 5 · 15 min on your wrist")
        #expect(String(localized: "Level \(5) · \(15) min on this iPhone", bundle: en) == "Level 5 · 15 min on this iPhone")
        #expect(String(localized: "\("4 in · 6 out") · \(2) min on your wrist", bundle: en) == "4 in · 6 out · 2 min on your wrist")
        #expect(String(localized: "Level \(5) · \(12) min left · tap to control", bundle: en) == "Level 5 · 12 min left · tap to control")
        #expect(String(localized: "\(2)-tap burst, strong, every \("0.9")s", bundle: en) == "2-tap burst, strong, every 0.9s")
        #expect(String(localized: "\("$9.99") / \(3) months", bundle: en) == "$9.99 / 3 months")
    }

    @Test func trialCopyMatchesWhatCapitalizingUsedToProduce() throws {
        let en = try enBundle()
        #expect(String(localized: "Try Queasy Pro\n\(7)-day free trial.", bundle: en) == "Try Queasy Pro\n7-day free trial.")
        #expect(String(localized: "Start My \(7)-Day Free Trial", bundle: en) == "Start My " + "7-day free trial".capitalized)
        #expect(String(localized: "\(1)-Month Free Trial, then \("$2.99 / month"). \("Terms.")", bundle: en)
            == "1-Month Free Trial, then $2.99 / month. Terms.")
    }

    @Test func percentSignsSurvive() throws {
        let en = try enBundle()
        #expect(String(localized: "SAVE \(58)%", bundle: en) == "SAVE 58%")
        #expect(String(localized: "SAVE 58%", bundle: en) == "SAVE 58%")
    }

    @Test func multiArgumentKeysKeepTheirOrder() throws {
        let en = try enBundle()
        #expect(String(localized: "\(4) in · \(6) out", bundle: en) == "4 in · 6 out")
        #expect(String(localized: "\("Pulse") · \("Motion sickness")", bundle: en) == "Pulse · Motion sickness")
        #expect(String(localized: "\("$14.99"). \("Terms.")", bundle: en) == "$14.99. Terms.")
    }

    /// A plan's tips are saved and synced in English, then looked up on screen.
    @Test func storedTipsAreEnglishCatalogKeys() throws {
        let en = try enBundle()
        for cause in NauseaCause.allCases {
            let checkIn = CheckIn(cause: cause, severity: 3, stillExposed: true, recentlyAte: false)
            let plan = PatternEngine.recommend(for: checkIn)
            #expect(!plan.tips.isEmpty)
            #expect(plan.displayTips == plan.tips)
            for tip in plan.tips {
                let missing = "MISSING"
                #expect(en.localizedString(forKey: tip, value: missing, table: nil) == tip)
            }
        }
    }

    @Test func labelsDrawnBesideANumberPickByCategory() {
        #expect(PluralLabel.category(1) == .one)
        #expect(PluralLabel.category(5) == .other)
        #expect(PluralLabel.queasyDays(1) == "queasy day")
        #expect(PluralLabel.queasyDays(2) == "queasy days")
        #expect(PluralLabel.calmDays(1) == "calm day")
        #expect(PluralLabel.calmDays(0) == "calm days")
        #expect(PluralLabel.sessionsThisWeek(1) == "sessions\nthis week")
        #expect(PluralLabel.sessionsThisWeek(3) == "sessions\nthis week")
    }

    @Test func wholeSentenceHeadingsMatchTheLabelsTheyReplaced() {
        for cause in NauseaCause.allCases {
            #expect(cause.suggestedHeading == "Suggested for \(cause.label.lowercased())")
        }
    }

    @Test(.enabled(if: Locale.current.identifier == "en_US", "US English wording only"))
    func formattersKeepUSEnglish() {
        #expect(DisplayFormat.clock(245) == "4:05")
        #expect(DisplayFormat.clock(5) == "0:05")
        #expect(DisplayFormat.clock(-3) == "0:00")
        #expect(DisplayFormat.clock(2700) == "45:00")
        for spec in PulseSpec.levels {
            #expect(DisplayFormat.oneDecimal(spec.interval) == String(format: "%.1f", spec.interval))
        }
        for value in [-1.25, -0.04, 0.0, -0.0, 0.04, 1.3, 2.0] {
            #expect(DisplayFormat.signedOneDecimal(value) == String(format: "%+.1f", value))
        }
    }

    static let languages = ["id", "ja", "nl", "pt-BR", "ru", "th", "vi", "zh-Hans"]

    private func bundle(_ language: String) throws -> Bundle {
        for host in [Bundle.main] + Bundle.allBundles {
            if let path = host.path(forResource: language, ofType: "lproj"), let bundle = Bundle(path: path) {
                return bundle
            }
        }
        throw LocalizationMissing(language: language)
    }

    @Test func everyLanguageTranslatesThePlurals() throws {
        for language in Self.languages {
            let host = try bundle(language)
            let locale = Locale(identifier: language)
            let text = String(localized: "\(10) minutes", bundle: host, locale: locale)
            #expect(!text.contains("#@"), "\(language): \(text)")
            #expect(text != "10 minutes", "\(language)")
            #expect(text.contains("10"), "\(language): \(text)")
        }
    }

    @Test func russianPicksPluralCategories() throws {
        let russian = try bundle("ru")
        let locale = Locale(identifier: "ru")
        let forms = [1, 3, 5].map { String(localized: "\($0) minutes", bundle: russian, locale: locale) }
        #expect(Set(forms.map { $0.dropFirst(2) }).count == 3, "\(forms)")
    }
}

private struct LocalizationMissing: Error {
    let language: String
}
