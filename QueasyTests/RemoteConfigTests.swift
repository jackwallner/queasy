import Foundation
import Testing
@testable import Queasy

/// The offering-metadata reader behind wording tests run without a release.
/// A missing, non-string or unknown value must read as the control, and the
/// control must be the copy that shipped before the reader existed.
struct RemoteConfigTests {
    @Test func missingNonStringAndUnknownValuesAreTheControl() {
        #expect(TrialCTA.from(metadata: nil) == .sevenDay)
        #expect(TrialCTA.from(metadata: [:]) == .sevenDay)
        #expect(TrialCTA.from(metadata: ["trial_cta": 7]) == .sevenDay)
        #expect(TrialCTA.from(metadata: ["trial_cta": true]) == .sevenDay)
        #expect(TrialCTA.from(metadata: ["trial_cta": "their"]) == .sevenDay)
        #expect(TrialCTA.from(metadata: ["trial_cta": "MY"]) == .sevenDay)
    }

    @Test func eachKnownValueIsItsArm() {
        #expect(TrialCTA.metadataKey == "trial_cta")
        #expect(TrialCTA.from(metadata: ["trial_cta": "seven_day"]) == .sevenDay)
        #expect(TrialCTA.from(metadata: ["trial_cta": "my"]) == .my)
        #expect(TrialCTA.from(metadata: ["trial_cta": "your"]) == .your)
    }

    /// The control is exactly what the paywall said before, for any trial length.
    @Test func controlTitleIsThePreChangeCopy() {
        let before = String(localized: "Start My \(7)-Day Free Trial")
        #expect(before == "Start My 7-Day Free Trial")
        #expect(TrialCTA.sevenDay.paywallTitle(controlTitle: before) == before)
        let fortnight = String(localized: "Start My \(14)-Day Free Trial")
        #expect(TrialCTA.sevenDay.paywallTitle(controlTitle: fortnight) == fortnight)
        #expect(TrialCTA.sevenDay.paywallButtonTitle(isLifetime: false, trialTitle: before) == "Start My 7-Day Free Trial")
    }

    @Test func eachArmHasItsTitle() {
        let control = "Start My 7-Day Free Trial"
        #expect(TrialCTA.my.paywallTitle(controlTitle: control) == "Start My Free Trial")
        #expect(TrialCTA.your.paywallTitle(controlTitle: control) == "Start Your Free Trial")
        #expect(TrialCTA.my.paywallButtonTitle(isLifetime: false, trialTitle: control) == "Start My Free Trial")
        #expect(TrialCTA.your.paywallButtonTitle(isLifetime: false, trialTitle: control) == "Start Your Free Trial")
    }

    /// No arm promises a trial to an account that already used it (3.1.2), and
    /// lifetime keeps its own button.
    @Test func ineligibleAndLifetimeWordingIsUnchanged() {
        for arm in TrialCTA.allCases {
            #expect(arm.paywallButtonTitle(isLifetime: false, trialTitle: nil) == "Start Queasy Pro")
            #expect(arm.paywallButtonTitle(isLifetime: true, trialTitle: nil) == "Unlock Lifetime")
        }
    }

    @Test func switchIsOnUnlessTheValueIsOff() {
        #expect(RemoteSwitch.ratingPrompt.rawValue == "rating_prompt")
        #expect(RemoteConfig.isOn(.ratingPrompt, in: nil))
        #expect(RemoteConfig.isOn(.ratingPrompt, in: [:]))
        #expect(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "on"]))
        #expect(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": false]))
        #expect(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "OFF"]))
        #expect(!RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "off"]))
    }
}
