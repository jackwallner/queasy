# Queasy audit823

Audit date: 2026-08-23

Scope: Queasy only, /Users/jackwallner/queasy.

This is a fresh max-reasoning rerun. The audit is read-only. It covers local source, project configuration, StoreKit configuration, Fastlane metadata, website and legal files, screenshots, agent documentation, and the App Store Connect and RevenueCat status evidence available in the surrounding context. No app code, configuration, metadata, website, or other file was changed by this audit.

Evidence labels:

- Evidence: directly present in the repository or in the dated ASC context snapshot.
- Inference: a likely conversion, reliability, or UX consequence that needs product or production validation.
- Recommendation: a concrete next action for the implementation agent.

Important limits:

- There is no per-app ASC analytics export in the repository or available context for downloads, impressions, product-page conversion, crash rate, or ratings.
- There is no reliable per-app Queasy RevenueCat dashboard export for trial starts, active trials, trial conversion, churn, or revenue. Fleet-level RevenueCat totals must not be attributed to Queasy.
- No live device session, TestFlight cohort, paid purchase, watch handoff, or production crash was exercised in this audit.
- The ASC status below is a context snapshot, not a substitute for pulling current app, version, product, and crash data before implementation.
- Per the request, this audit does not treat RevenueCat processing of subscription identifiers as a data-collection inconsistency defect.

## Executive assessment

Queasy has a strong free-first conversion shape: onboarding does not block the product behind a paywall, all four modes can be tried, the app supports iPhone-only use, and Pro is attached to understandable expansion features such as longer sessions, history, custom rhythm, and reminders. The current implementation also has unusually careful medical-claim guardrails and an explicit positive-moment review flow.

The largest immediate risks are consistency and measurement rather than a lack of monetization surfaces:

1. The landing page uses old screenshots and old product naming while the current store metadata and app are for the four-mode 1.1.0 product. The old website screenshots make claims about a comfort band and P6-area wrist pulses that the current product explicitly disclaims.
2. The current screenshot set contains a Breathe capture that says the device has no haptic engine, and a morning-sickness recommendation capture that conflicts with the documented decision to keep pregnancy out of screenshots. These assets need an explicit approval decision before use in ASC or the website.
3. The app does not collect enough durable funnel data to answer where downloads become first sessions, capped sessions, paywall views, trial starts, paid conversions, reviews, or watch sessions. Local OSLog events are not a production funnel.
4. Purchase state has a user-visible ambiguity: a completed RevenueCat purchase that has not yet surfaced an active entitlement is presented as approval pending, even when the underlying state may simply be propagation or an unclassified StoreKit result.
5. The free-session cap is inferred from requested duration when the post-session upgrade prompt should use actual elapsed duration. A short free session can therefore be labeled as capped.
6. Watch handoff failures and local store recovery are mostly silent. A user can lose an expected watch session or history without a durable diagnostic signal.
7. Several root documents still describe the retired hard-paywall, old product name, and old prices. A Cursor, Claude, or Codex agent can follow those instructions and regress the current product.

### Priority summary

| Priority | Finding | Evidence | Consequence | Recommended disposition |
| --- | --- | --- | --- | --- |
| P0 | Website proof is stale | index.html:503-518 points to root appstore-screenshot-01.png through 06.png; those images contain the old comfort-band and P6-area wording. Current assets are under fastlane/screenshots/en-US/. | Paid or organic traffic sees a different and less defensible product than the store listing. | Replace or deliberately rebuild the website gallery, title, OG data, and JSON-LD as one release task. |
| P0 | Current screenshot approval is unsafe | fastlane/screenshots/en-US/appstore_02_breathe.png shows a no-haptic-engine warning; appstore_04_match.png exposes morning-sickness copy despite the screenshot guardrail in CLAUDE.md. | Store conversion and review risk. A screenshot can advertise an unavailable experience or create a claim-policy contradiction. | Do not publish these captures until the source state, target device, and claim decision are fixed and re-reviewed. |
| P1 | Trial and purchase state is under-instrumented and partly ambiguous | Shared/Services/SubscriptionService.swift:205-222,237-263; Shared/Services/AnalyticsService.swift:1-42. | Trial starts, offer eligibility, pending purchases, and conversion failures cannot be diagnosed. Some users may see an inaccurate pending message. | Add explicit purchase state, offer state, and durable event contracts before major paywall experiments. |
| P1 | Capped-session upgrade prompt can be wrong | Queasy/Views/PhoneSessionView.swift:266-297 calls FreeTier.isCapped with requested duration rather than actual elapsed duration. | A user who voluntarily ends at 30 or 90 seconds can receive a message implying the free limit interrupted them. | Calculate actualSeconds >= cap and separately record voluntary, cancelled, expired, and capped endings. |
| P1 | Watch and persistence failures are silent | Shared/Services/QueasySyncService.swift, QueasyWatch/Services/WatchHapticEngine.swift, Shared/Services/DataService.swift. | Missed handoffs, lost episodes, and store recovery cannot be distinguished from normal abandonment. | Add retry, timeout, recovery, and release-version signals, then validate on paired devices. |
| P1 | No live-user crash or release-regression watchdog exists | No MetricKit, Sentry, Firebase Crashlytics, App Center, or ASC ingestion code was found. AnalyticsService only writes local logs. | A Mac script cannot alert on live user crashes from this repository alone. A release spike can be discovered late. | Use ASC crash and hang data or an approved telemetry backend, with version comparison and alert thresholds. |
| P1 | Current agent instructions are contradicted by root docs | docs/scope.md, docs/positioning.md, aso-plan.md, and a release script still contain old names, prices, or hard-paywall instructions. | Future agents can undo the current free-first and claim-safe product decisions. | Mark historical documents clearly or move them under archive/; establish one current source-of-truth table. |
| P2 | Localized ASO fields leave search surface unused | All 50 locale directories exist, but many translated names and keyword fields are materially shorter than the available limits. | Potentially lower search coverage and weaker local relevance. | Use query evidence to add unique local terms, then validate translations and policy, not blind padding. |
| P2 | Review funnel is ethically gated but not measurable | Shared/Services/ReviewPromptTracker.swift, Queasy/Views/ReviewPromptSheet.swift; no native review API or review events found. | The team cannot measure prompt reach, feedback rate, review-link opens, or timing. | Add coarse funnel events and validate the direct App Store URL on device. |
| P2 | Paywall is vulnerable to offer, localization, and layout edge cases | Queasy/Views/PaywallView.swift:14-805 has hardcoded trial timeline language, a non-scroll layout, and eligibility that starts empty. | Users can see incomplete, misleading, or clipped purchase copy in some states and locales. | Add loading and localized StoreKit tests, then run source-specific experiments. |

## 1. App Store Connect, download, and ASO audit

### Status evidence

- Context ASC snapshot dated 2026-08-23: app ID 6786780495, name Queasy - Motion Sickness Aid, version 1.1.0, status Ready for Distribution.
- Local source of version and build: project.yml:15-22, marketing version 1.1.0, build 20.
- Older status text in docs/positioning.md:403-432 says WAITING_FOR_REVIEW on 2026-08-16. That is stale against the later context snapshot and should not be used for release decisions.
- fastlane/metadata/primary_category.txt is HEALTH_AND_FITNESS; secondary category is TRAVEL.
- fastlane/metadata/review_information/notes.txt gives the reviewer hardware and claim context. It is useful review evidence, but it is a historical review handoff, not a source of current product metrics.

Before acting on any status or conversion hypothesis, pull current ASC data for app ID 6786780495 and version 1.1.0, including:

- App units, impressions, product-page views, product-page conversion, source type, territory, device, and date.
- Ratings count, average rating, rating velocity, review text themes, and version distribution.
- Crashes, hangs, launch time, and crash-free users or sessions by version and build.
- Current localized metadata, screenshot order, app preview state, pricing, subscription availability, and introductory-offer availability by storefront.

### Metadata pipeline and current state

Evidence:

- scripts/build-metadata.py is the apparent canonical generator. It defines the current name, subtitle, keywords, URLs, category, 50 locale list, and field-length validation.
- There are 50 actual locale directories under fastlane/metadata, plus review_information.
- Every locale checked has name, subtitle, keywords, description, promotional text, support URL, marketing URL, privacy URL, and release notes.
- The current English-US values are:
  - Name: Queasy - Motion Sickness Aid
  - Subtitle: Wrist Vibration on Your Watch
  - Keywords: sick,carsick,seasick,car,sea,boat,plane,cruise,train,travel,dizzy,vertigo,nausea,100hz,breathe,tone
  - Support, marketing, and privacy URLs use https://jackwallner.github.io/queasy/.
- The current description and release notes describe four modes, free unlimited use, no account, Apple Watch and iPhone support, Pro features, one-week subscription trials, auto-renewal, and legal links.
- The generator validates maximum lengths, including name <=30, subtitle <=30, keywords <=100, and promotional text <=170. It does not enforce a minimum keyword utilization target, duplicate-token check, stale-term check, URL liveness, or claim consistency across website and screenshots.

Opportunities and risks:

1. English-US is close to the useful name and subtitle ceiling, which is good. The remaining ASO opportunity is query selection and conversion proof, not adding generic words to the title.
2. Many local names are short, including Japanese, Korean, Chinese, Hebrew, Hindi, Thai, Vietnamese, and several Indian locales. Many local keyword fields are also well below the available limit. This is an opportunity only if the terms are locally searched, accurately translated, and not redundant with the name or subtitle.
3. A few current fields appear optimized around motion sickness while the description also addresses morning sickness, hangover, vertigo, and nervous stomach. The claim guardrail intentionally keeps pregnancy out of the indexed name, subtitle, keywords, and screenshots. Validate the positioning decision with ASC query and conversion data before expanding it.
4. aso-plan.md:20 still describes the retired Queasy: Nausea Relief Band name and old metadata. scripts/build-metadata.py should be the only current metadata source an agent is told to edit.
5. scripts/asc-setup-release.py:45 still describes a paywall that gates the main experience. That is inconsistent with current free-first behavior and could cause an agent to recreate the retired funnel.
6. There is no repository-side evidence of product-page conversion, keyword rank, search term impressions, or review impact. Treat all ASO changes as experiments with a pre-change baseline.

### Metadata validation backlog

Recommendation for the implementation agent:

- Build a static metadata check that compares generated output to scripts/build-metadata.py, detects duplicate normalized tokens within each locale, rejects old product names and old price figures outside explicitly historical files, checks all URLs, and reports field utilization by locale.
- Add a human review queue for non-Latin keyword additions. Do not auto-translate or fill unused characters with unverified terms.
- Compare ASC metadata against the website title, OG title, JSON-LD name, screenshot copy, and product description before every release.
- Pull actual ASC search and conversion data before deciding whether motion sickness, nausea, travel sickness, morning sickness, vertigo, or hangover deserves a different field in each storefront.
- Separate metadata generation from historical planning documents. The current generator, not aso-plan.md, is the canonical implementation input.

## 2. Current trial and purchase flow

### User path

The current intended path is:

1. Download and launch.
2. Four-page onboarding in Queasy/Views/OnboardingView.swift:3-116.
3. User chooses watch setup, iPhone-only use, or a watch pairing path.
4. Queasy/App.swift:89-101 routes to RootTabView after onboarding. There is no production paywall before the first usable experience.
5. User starts from Quick Start, a mode card, or the four-stage check-in flow.
6. Pulse and Breathe are free for two minutes, Tone and Press run their fixed free protocols.
7. The user rates the session. Positive improvement can trigger the review flow. A capped-session milestone can trigger the upgrade flow.
8. The paywall can also be reached from a longer-session unlock note, the older History card, Settings, and mode-specific length controls.
9. The user selects yearly, monthly, or lifetime. Yearly is sorted first and is the default subscription selection.
10. RevenueCat performs the purchase. A successful active pro entitlement unlocks Pro and stores a local App Group status.

This is a reasonable value-first funnel. The main measurement gap is that the app does not persist or transmit the transitions between these steps.

### Products and offer evidence

Evidence:

- Queasy.storekit contains:
  - com.jackwallner.queasy.pro.monthly, $2.99, one-month period, one-week free trial.
  - com.jackwallner.queasy.pro.yearly, $14.99, one-year period, one-week free trial.
  - com.jackwallner.queasy.pro.lifetime, $29.99, nonconsumable lifetime purchase, no trial.
- Shared/Services/SubscriptionService.swift:78-108 formats an introductory-offer label from the StoreKit period and sorts yearly, monthly, lifetime.
- SubscriptionService uses RevenueCat entitlement pro and the Release appl_ key, while DEBUG uses the RevenueCat Test Store key. The simulator path avoids production configuration.
- project.yml:24-37 attaches Queasy.storekit to the Debug run and test actions.
- The current product and price claims in local English metadata and website JSON-LD match the base USD values in the local StoreKit file. Storefront prices and offer availability still require live ASC and RevenueCat verification.

Findings:

#### P1: Intro-offer eligibility can be presented as settled too early

Evidence: SubscriptionService.swift:205-222 initializes eligibility only for products with an introductory discount, clears it on failure, and isEligibleForIntroOffer defaults to false until RevenueCat responds. This is safe against falsely promising a trial, but PaywallView has no explicit eligibility-loading state.

Inference: an eligible user may first see a normal purchase CTA and then a trial CTA, or an ineligible user may see copy change after the paywall is visible. That can reduce trust and make trial-start attribution ambiguous.

Recommendation:

- Model eligibilityLoading, eligible, ineligible, and unknown separately.
- Keep the purchase CTA disabled or clearly labeled as checking the offer until the offer state is known, unless the product explicitly chooses a no-trial fallback.
- Record the offer state shown at impression and at purchase attempt.
- Test a first-time customer, a customer who used the trial, a restore, a family-shared entitlement, and a RevenueCat outage.

#### P1: Purchase result can be called pending without proving a pending transaction

Evidence: SubscriptionService.swift:237-263 calls RevenueCat purchase, applies the returned customer info, returns cancelled for a user cancellation, returns purchased if isProSubscriber is true, and otherwise returns pending. PaywallView presents the pending result as approval pending.

Inference: an entitlement propagation delay or an unclassified result may be shown as approval pending. The user can think a purchase is awaiting approval when it is actually still processing or needs a retry.

Recommendation:

- Distinguish StoreKit deferred or pending transactions, network processing, entitlement propagation, and an unexpected no-entitlement response.
- After a successful transaction response without an entitlement, poll or refresh customer info for a bounded period before presenting a retry path.
- Make the UI say Processing your purchase unless the transaction is specifically deferred or pending approval.
- Add a receipt or transaction identifier to internal diagnostics only, never to user-facing copy.
- Test sandbox cancellation, Ask to Buy or deferred approval if supported, revoked purchase, no-network restore, and backend entitlement propagation.

#### P1: Entitlement matching is too broad for reliable monetization diagnostics

Evidence: SubscriptionService.swift:265-270 unlocks Pro when the canonical pro entitlement is active or when any active entitlement exists.

Inference: a misnamed, legacy, or unrelated active entitlement can unlock Pro while local funnel and revenue reporting still says the expected entitlement is missing. This protects some customers from a configuration mistake but hides the mistake.

Recommendation:

- Make pro the only production unlock entitlement, or define an explicit migration map with an expiry date.
- Log the matched entitlement ID and product ID in internal diagnostics.
- Add a test that an unrelated active entitlement does not unlock Pro.

#### P2: Trial timeline text is not fully data-driven

Evidence: Queasy/Views/PaywallView.swift:234-270,456-494 describes Day 5 and Day 7, and the mock paywall hardcodes a seven-day trial. Runtime labels derive the offer period in some places, but the timeline still assumes seven days.

Inference: if the offer changes by storefront, product, or experiment, the timeline can say Day 7 while the selected offer has a different duration.

Recommendation: derive every day label and first-charge sentence from the selected introductory offer, and include an explicit fallback for no intro offer. Verify the exact renewal date wording in each supported locale.

#### P2: The debug mock can drift from the live paywall

Evidence: PaywallView.swift:449-496 contains a static screenshot/mock path with fixed prices, savings, and trial text.

Inference: screenshot QA can pass against copy that differs from the RevenueCat package state used in production.

Recommendation: make the mock fixture explicit and generated from the same product fixture as StoreKit tests, and label it as screenshot-only in the agent runbook.

### Paywall entry points and attribution

Current impression IDs found in the code:

- queasy_screenshot, debug-only in App.swift.
- queasy_settings, SettingsView.swift:128.
- queasy_after_session, PhoneSessionView.swift:294 and RootTabView.swift.
- queasy_history, HistoryView.swift:52.
- queasy_session_length, CheckInView.swift:345.
- queasy_mode_length, ModeStartView.swift:77.

SubscriptionService.trackPaywallImpression records the ID through RevenueCat's custom paywall impression API and calls AnalyticsService.paywallShown, but the local analytics event only contains the paywall ID. There is no package selected, CTA tapped, trial eligible, trial started, restore, purchase error, or purchase source event.

Required funnel dimensions:

- App version and build.
- Paywall source ID and presenting screen.
- Offer or experiment variant.
- Storefront and currency, preferably supplied by StoreKit or RevenueCat rather than inferred.
- Product ID and package type selected.
- Intro-offer state at impression, selection, and purchase.
- Paywall load result: loading, loaded, empty, or error.
- CTA result: purchase, cancellation, pending/deferred, failure, or entitlement success.
- Whether the user completed a first session before the impression.
- Whether the user arrived after a real cap, a history unlock, a reminder, Settings, or a pre-session note.

## 3. RevenueCat and custom-attribute audit

### What is present

- Shared/Services/SubscriptionService.swift configures RevenueCat, fetches offerings, checks intro eligibility, purchases packages, restores purchases, observes customer updates, and stores a local Pro flag.
- The local analytics service calls Purchases.shared for paywall impressions, but the rest of the event service is only OSLog.
- No RevenueCat setAttributes, setAttribute, user login, email, or stable customer identity call was found in the Queasy source.
- No Queasy-specific RevenueCat offering ID, experiment assignment, or per-app dashboard export was available in context.

### Safe attributes worth considering

RevenueCat attributes are best for low-cardinality, current customer segmentation. They should not become a replacement for an event stream and should not contain raw health or symptom history.

| Attribute | Allowed values | Set or update at | Use |
| --- | --- | --- | --- |
| app_version | 1.1.0 | After RevenueCat configuration and on version change | Segment offer and entitlement issues by release. |
| app_build | 20 | After configuration | Correlate release regressions. |
| onboarding_complete | true or false | Each onboarding completion CTA | Separate download-to-onboarding from first-session loss. |
| first_session_complete | true or false | First durable session completion | Distinguish value discovery from purchase timing. |
| watch_paired | true or false | Pairing state changes in QueasySyncService | Compare watch-required friction with iPhone-only use. |
| haptics_available | true, false, or unknown | First capability check and changes | Explain why a user did not feel Pulse or Breathe. |
| last_mode | pulse, breathe, tone, press | Confirmed session completion | Segment product usage without storing symptom details. |
| last_paywall_source | Existing source IDs | Paywall impression | Compare entry surfaces as last-touch context. |
| trial_offer_state | eligible, ineligible, unknown, not_applicable | Offer eligibility result | Investigate offer presentation. |
| free_cap_reached | true or false | Confirmed session ending at the cap | Test whether the cap creates useful upgrade intent. |
| experiment_variant | Short controlled ID | Assignment time | Tie RevenueCat customer outcomes to a declared experiment. |

Do not put these in RevenueCat custom attributes:

- Free-text check-in answers.
- Raw nausea cause, severity, relief delta, or medical context.
- Every session as a mutable attribute. Use events or a local aggregate instead.
- Timestamps or identifiers that create unnecessary personal history.
- A guessed trial-start flag before StoreKit or RevenueCat confirms the transaction.

### Exact insertion points

1. Add a queued attribute update after Purchases.configure succeeds in SubscriptionService.configure, and flush it after fetchProducts completes. Do not attempt the update on the simulator's local-default path.
2. Update onboarding_complete in the three completion actions in OnboardingView, after the setting is persisted.
3. Update watch_paired and haptics_available in the existing pairing and capability paths, not only when the Home screen appears.
4. Update last_paywall_source in PaywallView after the impression has been accepted, while emitting a separate immutable impression event.
5. Update first_session_complete, last_mode, and free_cap_reached from the shared session-completion path. Phone and watch paths must use the same event contract.
6. Set experiment_variant once per assigned experiment and retain the assignment for the test duration. Do not infer it from a UI string.

The implementation agent should first decide whether RevenueCat attributes are permitted by the product's privacy and analytics policy. The current audit only identifies useful segmentation points. It does not recommend adding account identity or changing the privacy policy.

## 4. Analytics, trial-funnel, and conversion instrumentation

### Current instrumentation

Shared/Services/AnalyticsService.swift:1-42 writes these local OSLog events:

- checkin_completed(cause,severity).
- session_started(source,intensity,cause).
- session_completed(source,minutes,relief?).
- sent_to_watch(intensity).
- paywall_shown(id).
- purchase_attempted(plan) and purchase_completed(plan).

Evidence: the logger uses subsystem com.jackwallner.queasy and a local analytics category. The source comment says it can be replaced if the portfolio standardizes a real SDK.

Missing durable events:

- App launch, onboarding page view, onboarding completion, and onboarding exit.
- Quick Start tap, mode card selection, check-in start, check-in completion, recommendation accepted, and iPhone fallback selection.
- Session requested duration, actual duration, mode, source, watch or phone execution, haptics availability, end reason, and save result.
- Free cap reached versus voluntary early completion.
- Watch command sent, watch acknowledgement, watch start timeout, watch ended, episode transferred, duplicate episode, and transfer retry.
- Paywall load started, loaded, empty, error, retry, impression, close, package selected, CTA tapped, offer eligibility result, purchase result, restore result, and entitlement refresh.
- Trial actually started, trial converted, trial cancelled, renewal, refund, entitlement revoked, and expiration. Transaction and RevenueCat data should remain the source of truth for billing events.
- Review prompt shown, positive or negative branch, feedback opened, review link opened, and prompt suppressed by cooldown or resolution.
- Reminder authorization requested, granted, denied, scheduled, delivered if observable, tapped, and session attributed to a reminder.
- Data store recovery, in-memory fallback, store deletion, sync failure, and haptic engine failure.

### Recommended event contract

Use one versioned event schema for phone and watch. At minimum:

    event_name
    event_schema_version
    app_version
    app_build
    source: phone | watch | system
    mode: pulse | breathe | tone | press | none
    surface_or_paywall_id
    requested_seconds
    actual_seconds
    end_reason: completed | user_cancelled | expired | free_cap | watch_expired | error | abandoned
    watch_paired
    haptics_available
    product_id
    offer_state
    experiment_variant
    timestamp

Keep cause, severity, and relief measurements out of RevenueCat attributes. If product analytics later stores them, document the minimum necessary values and retention separately.

The most important invariant is one logical session ID from start through completion, rating, watch transfer, and paywall follow-up. This prevents the watch and phone from counting the same session twice.

## 5. Ratings and review funnel

### Current flow

- Shared/Services/ReviewPromptTracker.swift:8-45 uses session milestones 2, 5, and 15, requires a positive relief delta, applies a 60-day cooldown, and permanently resolves the prompt after a rating or private feedback.
- Queasy/Views/ReviewPromptSheet.swift asks whether Queasy is helping. A positive answer opens the direct App Store write-review URL. A negative answer opens private email feedback at jackwallner+q@gmail.com.
- Queasy/Views/SettingsView.swift:102 exposes Rate Queasy directly.
- Shared/Utilities/AppStoreReviewLinks.swift:3-8 constructs https://apps.apple.com/app/id6786780495?action=write-review, which matches the ASC app ID context.
- No SKStoreReviewController, requestReview, or native review request was found.
- No review funnel analytics were found.

What is good:

- The prompt is tied to a completed session and positive outcome instead of first launch.
- A user who is not happy receives a private feedback path.
- The prompt is capped by a long cooldown and a resolved state.
- Settings provides an explicit route for users who independently want to rate.

Findings:

#### P2: The funnel is not measurable

Evidence: no shown, response, feedback, URL-open, or completion event exists.

Inference: the team cannot tell whether the prompt is missed, dismissed, opened, or converted into a rating. A rating change cannot be connected to a release or milestone.

Recommendation: add coarse events for review_prompt_shown, review_prompt_positive, review_prompt_negative, review_feedback_opened, review_link_opened, and review_prompt_suppressed. Do not log review text or personal health context.

#### P2: Session count includes non-positive ratings

Evidence: PhoneSessionView.saveEpisode increments settings.completedSessionCount for every rating choice, including Skip, Same, and Worse. The positive relief gate protects the public prompt, but the milestone counter still advances.

Inference: users who skip or report no improvement can consume the 2, 5, or 15 milestones, delaying a future positive prompt. This may be intentional, but it is not documented as a product choice.

Recommendation: decide whether milestones mean all completed sessions or only rated sessions with a usable outcome. Add tests for Skip, Same, Worse, Watch, and phone paths.

#### P2: Direct write-review routing needs device validation

Evidence: the URL has the correct app ID, but it leaves the app and depends on App Store routing.

Recommendation: validate on iPhone in each supported storefront, with App Store installed, no network, and the app not yet installed from the same Apple Account. Keep a fallback if UIApplication.open fails. If switching to the native review request, test Apple's quota behavior and do not remove the explicit Settings link.

### Review experiment ideas

- Control: current positive prompt after milestones. Variant: prompt after the first positive completed session, with the existing cooldown and resolution protection. Guardrail: session completion and negative feedback rate.
- Control: current two-step sheet. Variant: a shorter positive CTA with a visible Not really private-feedback option. Guardrail: do not hide the negative path or auto-submit a review.
- Test whether a one-time Settings reminder after a second positive session improves ratings without increasing support contacts.
- Test review prompt timing separately for watch and iPhone sessions. Do not let duplicate phone and watch completion events trigger two prompts.

## 6. Onboarding and core UX

### Onboarding

Evidence from Queasy/Views/OnboardingView.swift:3-116:

- Page 1 presents the four-mode concept and says the modes are free to use.
- Page 2 asks three quick questions or introduces the check-in concept.
- Page 3 explains the Apple Watch location and wrist guidance.
- Page 4 offers Get Started for paired users and iPhone-only continuation for users without a watch.
- The final disclaimer states that the app is not a medical device and does not diagnose, treat, or cure.
- Completion writes settings.hasCompletedOnboarding directly. There is no onboarding event.

Findings and recommendations:

- The watch is prominent before the user has received value. The iPhone-only path exists, which is good, but its copy frames it as an exception: I understand Queasy is designed for Apple Watch.
- Inference: users who download without a watch may interpret the app as unusable or abandon before discovering Tone and Press, even though those modes have an iPhone path.
- Recommendation: A/B test watch-first versus mode-first onboarding. In the no-watch branch, make the iPhone path a normal primary path and explain the watch benefit as an enhancement.
- Add page-level exit events and completion events. Measure download to onboarding completion, completion to first session, and first session source.
- Validate Dynamic Type, VoiceOver labels, Reduce Motion, right-to-left layout, and long translated strings. The current page count and progress indicators should remain understandable when text wraps.

### Check-in and recommendation

Evidence from Queasy/Views/CheckInView.swift:4-576:

- The visible flow has cause, severity, a context page with two questions, and recommendation.
- The implementation uses four progress stages even though the marketing language refers to three quick questions or answers.
- The cause choices include motion, morning sickness, hangover, vertigo, anxiety, and general illness.
- The recommendation selects a mode through PatternEngine, applies the two-minute free cap when appropriate, stores the last plan, and offers watch or iPhone start.
- Morning-sickness guidance includes a prominent escalation note for inability to keep fluids down.

Recommendations:

- Measure each automatic advance and the number of users who leave on the combined context page. Two questions on one page may be efficient, but it is the most information-dense step.
- Test whether the recommendation explanation is enough for a user to understand why a mode was chosen without opening Learn.
- Keep unlockLengthNote secondary to the free Start action until the user has experienced value. Test a pre-session paywall against the current free start control, with first-session completion as a guardrail.
- Make the three-answer versus four-stage wording explicit in copy so the progress indicator never feels inconsistent.

### Session experience

Evidence:

- Queasy/Services/PhoneSessionController.swift:24-111 starts and stops phone sessions, prevents idle sleep, resets the haptic engine on reset, persists unrated sessions on finish, and drops very short cancellation sessions under 60 seconds.
- Queasy/Views/PhoneSessionView.swift:266-297 saves the rating, calculates upgrade eligibility, increments the completed count, and triggers review or upgrade prompts.
- Shared/Services/FreeTier.swift:14-31 sets free Pulse and Breathe sessions to 120 seconds while Tone and Press use their full fixed protocols.
- Queasy/Views/RelieveHomeView.swift:161-318 offers Quick Start, mode cards, watch start, and iPhone fallback.

Findings:

#### P1: Capped state is not based on actual elapsed time

Evidence: PhoneSessionView.saveEpisode passes controller.plan.durationMinutes * 60 as the requested value to FreeTier.isCapped, not the stored actual duration. A free Pulse or Breathe plan longer than 120 seconds is therefore treated as capped even if the user ends at 30 or 90 seconds.

Recommendation: pass the actual elapsed seconds and retain the requested-versus-granted distinction. Show an upgrade prompt for an actual cap or an attempted locked duration, not for any free plan whose configured duration exceeds two minutes.

Acceptance test:

- Free Pulse requested for 10 minutes, ended at 30 seconds: not capped.
- Free Pulse requested for 10 minutes, stopped at exactly 120 seconds by the cap: capped.
- Free Pulse requested for 10 minutes, watch expires at 120 seconds: capped.
- Tone one-minute and Press three-minute sessions: never classified as a free Pulse/Breathe cap.
- Pro session: never classified as capped.

#### P2: Very short cancelled sessions disappear without a user-visible explanation

Evidence: PhoneSessionController.cancel drops sessions shorter than 60 seconds, while no abandoned-session event exists.

Inference: accidental taps, haptic failure, or confusion may look like no usage. The implementation agent cannot distinguish a healthy short cancel from a broken start.

Recommendation: preserve a lightweight local diagnostic event and expose a retry or hardware hint when start failure is suspected. Do not necessarily add a history entry for every accidental cancel.

#### P2: Haptics availability is disclosed, but it is not part of the funnel

Evidence: the phone UI warns when no haptic engine is available and says Tone still works. The review notes also explain that iPad compatibility mode cannot provide the expected experience.

Recommendation: log capability state, device family, selected mode, and fallback. Ensure the ASC screenshot device is an iPhone with the intended capability, not a no-haptic simulator or iPad compatibility frame.

### Watch experience and sync

Evidence:

- QueasyWatch/Services/WatchHapticEngine.swift uses WKExtendedRuntimeSession, sends session state, handles expiration, and sends unrated or rated episodes back to the phone.
- Shared/Services/QueasySyncService.swift uses sendMessage, application context, and transferUserInfo with App Group persistence.
- A stale auto-start guard treats plan handoffs older than 10 minutes as ordinary handoffs.
- transferUserInfo and watch command paths have silent or best-effort failure branches. There is no durable retry or timeout event.
- Watch completion logs a completion event, then phone sync can log a corresponding completion when it persists the payload. A logical session ID is not part of the current analytics contract.

Recommendations:

- Add a handoff state machine: requested, delivered, acknowledged, started, ended, transferred, persisted, and failed.
- Give watch start a visible timeout and an iPhone fallback if no acknowledgement arrives.
- Retry episode transfer until the phone confirms persistence, with a bounded queue and duplicate UUID upsert.
- Use one session ID across watch and phone, and deduplicate completion events.
- Test phone locked, watch locked, watch out of range, Bluetooth temporarily unavailable, phone app terminated, watch app not opened recently, stale plan, watch runtime expiration, and reconnect after a transfer failure.
- Ensure an iPhone-only user never sees a dead-end watch instruction after choosing the iPhone path.

### History, Learn, settings, and reminders

Evidence:

- Queasy/Views/HistoryView.swift:18-154 shows the last seven days for free users, retains older episodes locally, and uses an older-session card to open Pro.
- The History screen provides stats, best mode, heatmap, CSV export, and deletion.
- Queasy/Views/LearnView.swift:1-140 explains all four modes, links to PubMed, ScienceDirect, DOI, Cochrane, NHS, and ACOG material, and uses careful non-treatment language.
- Queasy/Services/PressReminderService.swift gates local reminders behind Pro and schedules fixed times at 8, 14, and 20.

Findings and recommendations:

- The retained-but-hidden history copy is a good upgrade explanation. Add an event for older-card view, paywall open, export, heatmap view, and deletion so retention features can be evaluated.
- Verify the empty History state has a clear Start a session action. The current text-first empty state can add navigation friction after onboarding.
- The Learn cards are long. The current appstore_05_sources.png capture appears to have source content partly obscured or clipped near the bottom tab bar. Rebuild the screenshot with a deliberate scroll position and a shorter above-the-fold excerpt.
- Add a link health check for every hardcoded source URL, including HTTP status and expected title. A broken source link undermines the evidence-first positioning.
- Measure notification authorization grant, denial, schedule success, and reminder-originated sessions. try? in local notification setup otherwise makes permission or scheduling failures invisible.
- Test reminder times across daylight saving changes, time zones, locale formatting, and Pro lapse or restore.

## 7. Paywall and A/B test opportunities

### Current paywall observations

Evidence from Queasy/Views/PaywallView.swift:14-805:

- The paywall is custom SwiftUI, not a RevenueCat Native Paywall implementation in this repository.
- The default runtime state loads RevenueCat packages; loading, empty, offline, and content states are present.
- The current design emphasizes sessions up to 45 minutes, history, custom rhythm, and reminders.
- Yearly is selected first, has a savings badge, and is followed by monthly and lifetime options.
- Trial CTA and disclosure text change based on selected package and eligibility.
- Legal footer includes restore, Terms, and Privacy links.
- The layout uses a non-scrolling vertical stack with fixed disclosure sizing and a footer row. Long translations and Dynamic Type may overflow or clip.

Prioritized tests:

| Test | Control | Variant | Primary metric | Guardrails |
| --- | --- | --- | --- | --- |
| Post-value timing | Current capped milestone at 3, 8, 20 sessions | First confirmed real cap, with cooldown | Paywall view to trial start and trial conversion | Session completion, rating, uninstall or support signal |
| First paywall headline | Sessions as long as you need | Outcome-neutral clarity, such as Keep every session going | Paywall CTA rate | Refund, cancellation, negative feedback |
| Trial CTA | Current dynamic trial CTA | Start my 7-day free trial or equivalent localized copy | Trial starts per eligible paywall view | Purchase errors and early cancellations |
| Package default | Yearly selected first | Monthly default or explicit recommendation based on price sensitivity | Eligible paywall to paid conversion and revenue per view | Refunds, churn, lifetime mix |
| Lifetime anchor | Current yearly, monthly, lifetime ordering | Test lifetime position and value framing without dark patterns | Revenue per paywall view | Lifetime cannibalization and refund rate |
| Source-specific content | Same paywall content for every entry | History, session-length, Settings, and post-session copy matched to intent | Conversion by source ID | Session completion and close rate |
| Pre-session unlock | Length note can open the paywall before the first session | Hide or defer until after first completed session | First-session completion to first paywall | Trial start and day-7 retention |
| Watch value explanation | Watch is emphasized in onboarding | Explain iPhone-first value, then watch enhancement | Onboarding to first session | Watch pairing, support contacts |
| History gate | Older card opens Pro | Show a preview count and concrete value before paywall | History paywall conversion | History visits and retention |
| Offer-state handling | CTA can appear before eligibility settles | Show checking state or explicit no-trial state | CTA comprehension and trial starts | Purchase errors and abandonment |

Experiment rules:

- Assign a stable variant before the first paywall impression, persist it, and include it in every event.
- Do not compare different entry sources as if they were randomized variants.
- Use RevenueCat offering or experiment controls only after confirming that the Queasy project and entitlement configuration are current. No Queasy-specific experiment evidence was available in context.
- Keep the no-paywall onboarding path as the control for first-session value. Monetization experiments should not remove the ability to try the product.
- Use trial starts, first renewal, paid conversion, refunds, and retention together. Paywall taps alone are not success.
- Test StoreKit sandbox or RevenueCat test products with real eligible and ineligible customer states. A bare simulator screenshot is not proof of live offer behavior.

### Paywall edge-case matrix

The implementation agent should validate:

- Products loaded, empty offering, transient network error, and retry.
- Eligible yearly, eligible monthly, lifetime selection, already-used trial, and no introductory offer.
- Localized price, currency, decimal formatting, savings rounding, and long product names.
- Restore before paywall, restore from another device, revoked entitlement, expired subscription, and family sharing if applicable.
- User cancellation, deferred purchase, Ask to Buy if applicable, entitlement propagation delay, and app termination during purchase.
- Offline presentation, legal footer links, back navigation, sheet dismissal, and repeated presentation.
- Dynamic Type, VoiceOver, RTL, small iPhone width, safe-area variations, and long localization strings.
- Test StoreKit file versus RevenueCat Test Store versus release device. Never use the production appl_ key on a simulator.

## 8. Website, terms, privacy, and consistency

### Concrete consistency matrix

| Surface | Current evidence | Status | Action |
| --- | --- | --- | --- |
| ASC and Fastlane name | Queasy - Motion Sickness Aid in current metadata and ASC context | Current | Keep as canonical unless an ASC experiment changes it. |
| Website document title | index.html:8, Queasy - Four Drug-Free Things to Try When You Feel Sick | Partly current | Keep the four-mode positioning, but align OG and JSON-LD names. |
| Website OG and Twitter name | index.html:13,20, Queasy - Wrist Nausea Relief | Stale | Change to the current approved product name or intentionally use a documented campaign name. |
| Website JSON-LD name | index.html:27, Queasy - Wrist Nausea Relief | Stale | Align with ASC and visible page copy. |
| Website screenshots | index.html:503-518 uses root appstore-screenshot-01.png through 06.png | Stale and high risk | Use current approved assets or rebuild the old assets. |
| Current store screenshots | fastlane/screenshots/en-US/appstore_01_four.png through _06_history.png | Needs review | Breathe warning, pregnancy capture, clipping, and device-state claims need approval. |
| Website host | Canonical and title use jackwallner.com; metadata URLs use GitHub Pages | Split | Confirm redirects, canonical tags, HTTPS, link health, and campaign attribution. |
| Support P6 guidance | support.html:27-29 says about two finger-widths below the crease | Inconsistent | Align with the current three-finger-width wording or document why support differs. |
| In-app P6 guidance | LearnView.swift says about three finger-widths below the crease | Current code | Use one approved wording in app, site, support, and screenshots. |
| Product pricing | StoreKit and local metadata show $2.99 monthly, $14.99 yearly, $29.99 lifetime | Base USD matches | Label website JSON-LD as base USD or avoid implying every storefront has these prices. Verify live prices. |
| Trial terms | Metadata and website say one-week subscription trials; terms.html says any introductory offer shown | Acceptable but broad | Decide whether the Terms should name the current one-week offer, then keep it synchronized with ASC. |
| Privacy policy | privacy-policy.html, updated Aug 17, 2026, describes local data and RevenueCat subscription processing | Present | Keep links current. Do not treat the RevenueCat disclosure as a defect for this audit. |
| Terms | terms.html, updated Aug 17, 2026, includes Apple EULA, renewal, cancellation, restore, and refund route | Present | Add a visible site footer link if the index page link audit confirms Terms is absent. |
| Safety copy | Website, support, Terms, Privacy, metadata, onboarding, Learn, and review notes contain non-treatment framing | Generally aligned | Run a claim-string scan and screenshot OCR before every submission. |

### Website conversion findings

#### P0: Old screenshots change the product promise

Evidence: root appstore-screenshot-01.png says The comfort band you already own and describes Apple Watch pulses on the P6 area. The current app and metadata say Pulse is not acupressure and does not claim to act on a nerve or body mechanism.

Inference: a visitor can arrive through the site expecting a treatment-like wristband experience, then find a different four-mode comfort app in the store. This is a conversion and trust failure, and it reintroduces the claim issue that the current product intentionally removed.

Recommendation: replace the gallery with current approved assets, update alt text and captions, and search the site for band, P6 area, Wrist Nausea Relief, and old mode claims. Historical images should be moved or clearly excluded from active site references.

#### P1: Current Breathe screenshot may advertise a broken experience

Evidence: fastlane/screenshots/en-US/appstore_02_breathe.png includes the warning that the device has no haptic engine and that wrist sessions need an Apple Watch.

Inference: an ASC user who sees this screenshot can believe the product does not work on the advertised device, even if the warning was only a simulator capture artifact.

Recommendation: rebuild the asset on an appropriate iPhone or use a deliberate watch capture. Add a screenshot preflight that rejects diagnostic warnings, simulator labels, unavailable-hardware messages, and debug UI.

#### P1: Pregnancy screenshot decision is unresolved

Evidence: fastlane/screenshots/en-US/appstore_04_match.png contains Suggested for morning sickness and safety copy. CLAUDE.md:104-133 says pregnancy is in the product and description but not in the name, subtitle, keywords, or screenshots.

Inference: uploading this asset would contradict the current documented review strategy and may reopen the exact category of review concern recorded in review_information/notes.txt.

Recommendation: choose one of two documented decisions before upload: remove pregnancy from the screenshot and keep it in the app description and in-app safety flow, or update the claim strategy and have the complete ASC submission re-reviewed. Do not leave the asset in an ambiguous approved-looking directory.

### Legal and disclosure notes

- terms.html and privacy-policy.html are dated Aug 17, 2026 and contain substantive current legal content.
- The Terms correctly describe subscriptions as auto-renewing, require cancellation at least 24 hours before the period ends, explain Apple billing, and provide restore and refund directions.
- The Privacy Policy distinguishes local check-ins and sessions from subscription processing. This audit does not score that as a RevenueCat tracking inconsistency, per instruction.
- support.html provides install, watch, restore, subscription management, safety, and contact guidance. It should link to the same current terms and privacy destinations as the app and store metadata.
- The website includes privacy and support links, but the active index navigation should be checked for a visible Terms link. A legal link that exists only in the paywall is easy for a pre-purchase visitor to miss.
- Run a link checker against all legal, support, App Store, PubMed, DOI, ScienceDirect, NHS, ACOG, and Cochrane URLs. Record status codes and final redirects.

## 9. Crash, regression, and watchdog audit

### Current signals and gaps

Evidence:

- No MetricKit, Sentry, Firebase Crashlytics, App Center, or equivalent crash SDK was found.
- No ASC API ingestion or scheduled crash report script was found in the Queasy repository.
- AnalyticsService only writes local OSLog events. Local logs cannot notify the developer when a different user's app crashes.
- DataService.swift removes the SwiftData store, WAL, and SHM files after a store error, then retries and can fall back to an in-memory container. The final in-memory setup uses try!.
- QueasySyncService.swift and watch command paths use best-effort sends and do not expose a durable failure queue.
- PressReminderService.swift uses try? around authorization and scheduling paths.
- RevenueCat product load and purchase errors are presented in the UI but not durable production diagnostics.

The most important architectural conclusion is that a MacBook script alone cannot detect a live user's crash. It can poll an external source such as ASC, Crashlytics, Sentry, or an approved backend, or inspect local device logs. The repository currently has neither a live crash feed nor a configured notification destination. A future scaffold can remain notification-disabled by default, as requested, but it must have an explicit data source.

### Recommended watchdog signals

| Signal | Source | Suggested trigger | Response |
| --- | --- | --- | --- |
| Crash-free users or sessions | ASC or crash backend | Drop versus previous release, with an absolute floor | Pause rollout, inspect top symbol and affected build. |
| Crash count by build | ASC or crash backend | New top crash or statistically significant spike after release | Link to symbolicated stack and release commit. |
| Hang or launch regression | ASC metrics, MetricKit, or device diagnostics | P95 launch or hang rate above baseline | Inspect startup tasks, RevenueCat setup, SwiftData, and WatchConnectivity. |
| Product load failure | App event stream or RevenueCat | More than baseline, especially empty offerings | Verify offering, storefront, network, and entitlement configuration. |
| Trial eligibility unknown | App event stream | Eligible cohort remains unknown after timeout | Inspect RevenueCat configuration and paywall state. |
| Purchase processing timeout | App event stream | No entitlement after bounded refresh window | Inspect StoreKit transaction and RevenueCat propagation. |
| Watch start timeout | App event stream | No acknowledgement after a short device-specific timeout | Show iPhone fallback and inspect connectivity. |
| Watch transfer backlog | App local queue or event stream | Queue grows or duplicate UUIDs rise | Retry and investigate reachability or phone termination. |
| Session start without completion | App event stream | Sessions exceed expected duration without end state | Detect hangs, app termination, watch expiration, or event loss. |
| Data store recovery | App event stream and local logs | Any store deletion or in-memory fallback | Preserve diagnostics, warn the user about possible local history loss, and investigate. |
| Reminder scheduling failure | App event stream | Authorization or scheduling failure above baseline | Show actionable Settings guidance. |
| Screenshot or metadata regression | CI static checks | Old names, URLs, claim strings, debug warnings, or wrong dimensions | Block metadata or website publish. |

### Release watch procedure

For every new build:

1. Record version, build, release time, and the previous comparison build.
2. Pull ASC crashes, hangs, launch metrics, ratings, and product-page metrics at 2 hours, 24 hours, and 72 hours.
3. Compare RevenueCat product loads, purchase errors, trial starts, and entitlement activations by build if the data source supports it.
4. Check watch start acknowledgement, episode transfer, and data recovery signals.
5. Inspect the top five crash or hang symbols and whether the first appearance aligns with the build.
6. Keep alert thresholds configurable. Starting thresholds such as a one percentage-point crash-free drop, a two percent product-load failure rate, or a ten percent watch-start timeout rate are hypotheses, not production policy, and must be tuned against baseline.
7. Keep notification sends disabled until the data source, recipient, rate limit, and false-positive handling are configured.

### Static watchdog checks that can run without AI

The requested future fleet script can perform these checks without an LLM:

- Parse project.yml and Queasy.storekit for bundle IDs, version, build, product IDs, price fixtures, and trial periods.
- Parse fastlane/metadata and scripts/build-metadata.py for missing fields, maximum lengths, duplicate tokens, URL consistency, old names, and old prices.
- Scan active HTML and source files for retired names, hard-paywall wording, unsupported claim strings, and stale ASC status text while excluding archive/ and explicitly historical review notes.
- Verify website image references exist, compare dimensions and checksums against approved screenshot manifests, and fail on root legacy image references.
- Use OCR or a manually maintained forbidden-string list to detect no haptic engine, simulator warnings, debug labels, and old medical-mechanism claims in submission screenshots.
- HTTP-check every current support, privacy, terms, App Store, DOI, PubMed, ScienceDirect, NHS, ACOG, and Cochrane URL, recording redirects and failures.
- Count test files and detect whether purchase, watch sync, DataService recovery, and UI flows have at least one test target.
- Run xcodebuild and the existing unit tests through the repo's headless simulator process, never a named simulator destination and never with the production RevenueCat key.
- Poll ASC or the approved crash backend when credentials are available, compare the current build to the previous build, and emit JSON plus a human-readable report. No notifications should be sent by default.

## 10. Cursor, Claude, and Codex documentation hygiene

### Current state

- AGENTS.md is a symlink to CLAUDE.md, which is a good single canonical agent entry point.
- CLAUDE.md correctly points agents to docs/positioning.md before changing copy, metadata, pricing, or site work, but that referenced document contains both superseded and current plans.
- No .cursor rules or Cursor-specific project instructions were found in the Queasy tree.
- No app-local .claude, .codex, or .agents instruction directory was found.
- No root README.md was found. A new agent must infer the project entry point from CLAUDE.md, project.yml, and scattered scripts.
- archive/README.md:1-8 clearly says archived files are historical and not current. This convention is good, but several stale documents remain outside archive/.

### Stale or confusing documents

| File | Evidence of staleness or ambiguity | Risk | Recommendation |
| --- | --- | --- | --- |
| docs/scope.md:1-124 | Old Queasy: Nausea Relief Band identity, old hard-paywall flow, old prices $4.99/mo, $29.99/yr, $69.99 lifetime, and retired feature descriptions. It also says pregnancy positioning was removed while the current product includes a guarded morning-sickness path. | An agent can restore the old paywall or claim language. | Move under archive/ or rewrite as a historical decision record with a prominent superseded banner. |
| docs/positioning.md:311-432 | Contains old ASO name and subtitle recommendations, old launch status, and a WAITING_FOR_REVIEW snapshot superseded by the later Ready for Distribution context. | An agent can edit current metadata toward obsolete positioning. | Split current positioning from dated experiments. Put the current name, subtitle, URLs, prices, product flow, and claim rules at the top. |
| aso-plan.md:20 | Uses old product name and old keywords; current generated metadata is elsewhere. | Metadata drift and accidental reversion. | Mark historical or replace with a short pointer to scripts/build-metadata.py. |
| scripts/asc-setup-release.py:45 | Release description says the paywall gates the main experience. | A release helper can encode the retired funnel in ASC copy. | Update its documentation in the implementation task and add a static stale-text check. |
| Shared/Services/SubscriptionService.swift:110 | Comment describes a hard paywall while runtime is free-first. | Code agents may assume paywall gating is intentional. | Change the comment in a separate implementation task, or include the current free-first behavior in the canonical doc. |
| ios27Queasy.md:1-25 | Dated Aug 5 compatibility audit with a narrow pass statement and an unreachable-code follow-up. | A current agent may treat it as a full current health audit. | Put it under archive/ or label it as a dated compatibility record and link the current test command. |
| fastlane/metadata/review_information/notes.txt:1-69 | Correctly explains the rejected 1.0 history and current claim changes, but it mixes historical rejection narrative with current review instructions. | It can be mistaken for current product requirements or metrics. | Keep it as review notes, but add a date and a pointer to current source-of-truth files. |
| Root directory | No current README or machine-readable project status manifest. | Slow onboarding and inconsistent agent decisions. | Add a concise current handoff document in a future non-audit change. |

### Recommended agent source-of-truth order

The implementation agent should be told to use this order:

1. CLAUDE.md and its AGENTS.md symlink for project rules.
2. project.yml, current source, and tests for implemented behavior.
3. scripts/build-metadata.py, scripts/locale-copy, and generated fastlane/metadata for store copy.
4. Queasy.storekit for local product fixtures, with live ASC and RevenueCat verification for production values.
5. terms.html, privacy-policy.html, support.html, and index.html for active site and legal copy.
6. archive/ only for historical rationale, never as an active to-do list.

The agent handoff should state explicitly:

- Free-first behavior is intentional. There is no initial production paywall.
- Current base products are monthly $2.99, yearly $14.99, lifetime $29.99, with one-week subscription trials in the current fixture.
- The four modes are Pulse, Breathe, Tone, and Press.
- Pulse is not acupressure and does not claim nerve stimulation.
- Morning sickness may remain an in-app guarded use case, but screenshot and indexed-metadata treatment requires an explicit current decision.
- Simulator runs must use StoreKit test configuration or a safe test key, never the production RevenueCat key.
- Website screenshots must come from an approved current manifest, not root legacy images.

## 11. Concrete implementation backlog

### P0, before any store or marketing refresh

1. Replace or quarantine the root legacy website screenshots. Update website title, OG title, JSON-LD name, alt text, and image references together.
   - Acceptance: active HTML references only approved current files; no old band or P6-area claims remain outside archive or explicitly historical review notes; site title and JSON-LD match the approved ASC name.
2. Resolve the current screenshot set.
   - Acceptance: no screenshot contains a simulator, no-haptics, debug, or unavailable-hardware warning; the pregnancy screenshot has a documented decision consistent with the current ASC claim strategy; sources and lower cards are legible.
3. Correct purchase-state wording and offer-state handling.
   - Acceptance: cancellation, deferred purchase, processing, entitlement success, and failure have distinct UI and analytics states; an eligible user cannot be charged immediately because eligibility was assumed incorrectly.

### P1, next release or before serious A/B testing

1. Fix actual-duration cap classification and add boundary tests.
2. Add versioned session, paywall, trial, review, watch, and recovery event contracts with one logical session ID.
3. Add watch acknowledgement, retry, duplicate prevention, and transfer diagnostics.
4. Stop silently deleting or falling back from a corrupted local store without a durable recovery signal and a user-safe recovery message.
5. Add ASC or approved crash-backend polling and release comparison to the future watchdog script. Keep notification sends disabled by default.
6. Canonicalize agent docs. Archive or label docs/scope.md, stale positioning sections, aso-plan.md, ios27Queasy.md, and obsolete release-script comments.
7. Test paywall layout and offer states under Dynamic Type, RTL, long locales, no network, trial-used customers, restore, and entitlement propagation delay.
8. Add UI and integration tests for onboarding branches, first session, free cap, rating prompts, paywall source IDs, purchase state, and watch handoff.

### P2, optimization and maintenance

1. Expand localized keywords only from ASC query and conversion evidence.
2. Add a current website Terms link and align support P6 guidance with in-app wording.
3. Add Review funnel events and device validation for the direct write-review URL.
4. Link Learn source health to a scheduled static check.
5. Test reminder permission, scheduling, delivery attribution, and Pro lapse behavior.
6. Experiment with post-value timing, CTA wording, package ordering, source-specific paywalls, and watch-first versus iPhone-first onboarding.

## 12. Validation plan for the implementation agent

### Static and repository validation

- Run the metadata generator and its length checks, then compare generated output with every active Fastlane locale.
- Search active files for Queasy: Nausea Relief Band, Wrist Nausea Relief, $4.99, $69.99, hard paywall, gates the main experience, and stale ASC status terms. Exclude archive/ and intentionally historical review notes only after reviewing each match.
- Verify every active website image reference, image dimension, checksum, and approved screenshot manifest entry.
- Check the website, support, terms, privacy, App Store, and scientific source URLs.
- Run unit tests and add focused tests for the cap boundary, purchase-state mapping, review milestones, and watch duplicate handling.

### Headless iOS validation

- Lease a shared headless simulator using the fleet's agent-sim checkout queasy process and target the returned UDID. Do not use a named simulator destination and do not open Simulator.app.
- Use Queasy.storekit or the RevenueCat Test Store key in DEBUG only. Never use the production appl_ key on a simulator.
- Exercise onboarding with no watch, paired-watch state, and haptics-unavailable state.
- Exercise Quick Start, check-in, each mode, free cap boundaries, rating choices, History older card, Settings, Learn links, and reminder settings.
- Use StoreKit testing or a release device for real offer presentation. A simulator screenshot with a debug mock is not proof of live ASC or RevenueCat copy.

### Device and TestFlight validation

- iPhone with haptics, iPhone with no usable haptic engine, and an iPhone paired with Apple Watch.
- Phone locked during watch session, watch locked, phone terminated, watch out of range, reconnect after transfer failure, watch runtime expiration, and stale plan handoff.
- New eligible subscription customer, trial-used customer, lifetime buyer, restore customer, revoked entitlement, purchase cancellation, deferred purchase, and no-network purchase.
- Small and large Dynamic Type, RTL, at least one long Latin locale, and one non-Latin locale with the full paywall and onboarding visible.
- Confirm that a real first session completes before a post-session paywall, that actual cap behavior is truthful, and that the review prompt cannot appear twice for one logical session.

### ASC and production validation

- Verify app ID 6786780495, version 1.1.0, build 20, metadata, screenshot order, app previews, product IDs, prices, introductory offers, and storefront availability.
- Establish a pre-release baseline for downloads, page conversion, first sessions, paywall views, trial starts, trial-to-paid conversion, refunds, rating velocity, crash-free users, hangs, product-load failures, and watch-start timeouts.
- Review at 2 hours, 24 hours, and 72 hours after release. Keep current and previous build visible in every report.
- Do not infer Queasy performance from fleet-level RevenueCat totals or unrelated app data.

## 13. Evidence inventory and final gaps

Primary local evidence reviewed:

- project.yml
- Queasy.storekit
- CLAUDE.md and AGENTS.md
- Shared/Services/SubscriptionService.swift
- Shared/Services/AnalyticsService.swift
- Shared/Services/FreeTier.swift
- Shared/Services/ReviewPromptTracker.swift
- Shared/Services/QueasySyncService.swift
- Shared/Services/DataService.swift
- Queasy/Views/OnboardingView.swift
- Queasy/Views/CheckInView.swift
- Queasy/Views/PhoneSessionView.swift
- Queasy/Views/WatchRemoteSessionView.swift
- Queasy/Views/PaywallView.swift
- Queasy/Views/HistoryView.swift
- Queasy/Views/LearnView.swift
- Queasy/Views/SettingsView.swift
- Queasy/Views/RelieveHomeView.swift
- QueasyWatch/Services/WatchHapticEngine.swift
- Queasy/Services/PhoneSessionController.swift
- Queasy/Services/PressReminderService.swift
- QueasyTests/
- fastlane/metadata/
- scripts/build-metadata.py
- scripts/build-screenshots.py
- index.html
- support.html
- terms.html
- privacy-policy.html
- docs/scope.md
- docs/positioning.md
- aso-plan.md
- ios27Queasy.md
- archive/README.md
- fastlane/metadata/review_information/notes.txt
- Shared/Utilities/AppStoreReviewLinks.swift

The most important missing evidence is live, per-version data. Before choosing an A/B winner or declaring the release healthy, obtain ASC metrics and crash data, Queasy-specific RevenueCat funnel data, storefront product and offer state, rating history, and a paired-device watch test. The repository currently supports a careful implementation, but it cannot by itself prove download conversion, trial conversion, revenue, crash rate, or live-user experience.
