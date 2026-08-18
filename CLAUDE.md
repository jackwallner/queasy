# CLAUDE.md: Queasy

iOS + watchOS app: four drug-free things to try when you feel sick, on the wrist
or in your ear. **Pulse** (a steady tap), **Breathe** (a paced breath you feel),
**Tone** (the 100 Hz minute from the 2025 Nagoya study), **Press** (coaching and
a timer for pressure the user applies at P6). Everything runs on Apple Watch
except Tone; iPhone Core Haptics covers users without a Watch.

Read `docs/positioning.md` before touching copy, metadata, pricing or the site.
It records why the app is shaped this way after the 1.1.6 rejections, and the
measured ASO data behind the metadata.

XcodeGen project/scheme: `Queasy`, sim lease owner `queasy`.

## Tech Stack

- Swift 6 / SwiftUI (strict concurrency)
- SwiftData (App Group container `group.com.jackwallner.queasy`)
- Core Haptics (iPhone fallback sessions), AVAudioEngine (100 Hz tone mode)
- WatchKit `WKExtendedRuntimeSession` (`physical-therapy` background mode) for
  background haptic playback on the Watch (no HealthKit)
- RevenueCat subscriptions (monthly / yearly / lifetime, entitlement `pro`)
- XcodeGen (`project.yml` → `Queasy.xcodeproj`), targets: iOS 17+, watchOS 10+

## Architecture

- `Shared/Models/ReliefEpisode.swift`: SwiftData episode log (before/after severity)
- `Shared/Models/ReliefPlan.swift`: `CheckIn`, `NauseaCause`, `ReliefPlan`, `PulseSpec`
- `Shared/Models/ReliefMode.swift`: the four modes, their copy, their citations,
  plus `BreathePattern` and `PressProtocol`
- `Shared/Services/FreeTier.swift`: the free ceiling and the `ProFeature` list
  the paywall renders from
- `Shared/Services/UpgradePromptTracker.swift`: when to offer Pro after a session
- `Shared/Services/PatternEngine.swift`: pure check-in → plan mapping (testable, the
  product's "algorithm"; 10 intensity levels, cause-specific caps and durations)
- `Shared/Services/DataService.swift`: App Group SwiftData container
- `Shared/Services/AppSettings.swift`: `@Observable` UserDefaults wrapper
- `Shared/Services/SubscriptionService.swift`: RevenueCat (`pro` entitlement)
- `Shared/Services/QueasySyncService.swift`: WCSession bridge: phone pushes plans,
  watch sends completed episodes back
- `Shared/Utilities/Theme.swift`: Tide design system (seafoam canvas, petrol ink,
  aqua brand, serif-italic ritual type)
- `Queasy/`: iOS UI: Onboarding → RootTab (Relieve / History / Learn / Settings),
  with no paywall in between. `RelieveHomeView` = quick start + check-in + the four
  mode cards; `ModeStartView` = one mode explained and started; `CheckInView`
  (3 questions) → `RecommendationView` (mode picker) → `PhoneSessionView`, whose
  stage swaps per mode, or send-to-watch.
- `QueasyWatch/`: watch app: `WatchHapticEngine` runs Pulse on a fixed-interval
  timer and Breathe/Press as a cancellable rhythm loop, inside an extended runtime
  session.

### Debug launch arguments (a headless sim can be launched, not tapped)

`-QueasyTab history|learn|settings`, `-QueasyScreen mode-<mode>|session-<mode>|checkin|recommend-<cause>`,
plus the older `-QueasyResetOnboarding`, `-QueasyProOverride`, `-QueasySeedDemoData`,
`-QueasyScreenshots`, `-QueasyPaywallScreenshot`, `-QueasyWatchSessionScreenshot`.

On the watch app, `-QueasyWatchScreen home-<mode>|session-<mode>|rating` (App Store
watch capture: lease a group with `agent-sim checkout queasy --watch`, build for
the watch UDID, install, launch with the argument, `simctl io screenshot` at
416x496). Give the app a couple of seconds after `simctl launch` before
capturing, or you photograph the previous screen.

## Watch background haptics: the load-bearing decision

Dual backing, chosen by how the session starts (`WatchHapticEngine.Backing`):

- **Watch-initiated**: `WKExtendedRuntimeSession` with
  `WKBackgroundModes = ["physical-therapy"]`. Exists precisely to play haptics
  in the background (up to 1 hour). Sessions cap at 45 min. No HealthKit.
- **Phone-initiated remote launch**: `WatchLauncher` (iOS) calls
  `HKHealthStore.startWatchApp(with:)` with a mind-and-body
  `HKWorkoutConfiguration`; the watch wakes in the background (where extended
  runtime sessions can't start) and runs an `HKWorkoutSession` instead. No
  workout builder is attached, so nothing is saved to Health/Fitness. Requires
  the HealthKit entitlement + workout-share auth on both targets; falls back
  to the queued WatchConnectivity handoff ("open Queasy on your watch") when
  auth is denied.

Plans travel via `QueasySyncService` with an `autoStart` flag (10-min
freshness guard); a remote launch starts immediately with the last/default
plan and adopts the fresh plan mid-session when WC delivers it.

## Products

`com.jackwallner.queasy.pro.monthly` $2.99 · `.pro.yearly` $14.99 · `.pro.lifetime`
$29.99 (cut 2026-08-14 from the fleet-raise ladder, a deliberate exception to the
no-blanket-cut rule; see `docs/positioning.md`). Both subscriptions carry a
1-week free trial.

**No paywall on the way in.** All four modes are free and unlimited. Free Pulse
and Breathe sessions cap at `FreeTier.sessionSeconds`; Tone and Press always run
their full protocol; the check-in and live intensity control are free too. Pro
buys length, full history, a custom rhythm, and Press reminders, and the paywall
bullets render from `ProFeature` so they cannot drift from the gates.

RevenueCat API key
lives in `SubscriptionService.apiKey`; DEBUG builds can use
`SubscriptionService.setLocalOverride(isPro:)`. Per-territory intro offers and
PPP/emerging-market discounts use the shared `asc-*` pricing scripts (see the
`ios-dev` skill); app-specific script here is `scripts/generate-icon.py`
(regenerates the 1024 icon).

## Claims guardrail (App Review 1.1.6, and EU MDR)

1.0 was rejected twice under **1.1.6 (false features)**, not 1.4.1. That
distinction is the whole guardrail: 1.4.1 is "medical apps get more scrutiny"
and disclaimers help; 1.1.6 means the feature does not do what you say, and
Apple states outright that caveats cannot cure it. Full analysis in
`docs/positioning.md`.

**The one rule.** Look at the subject of the sentence. If the app or the watch
is the subject and the verb acts on the body ("Queasy relieves your nausea"),
it is a 1.1.6 risk. If the user is the subject and the app is the instrument
("follow a paced breath on your wrist"), it is fine.

House style, taken from Dizzout, the freshest approval in this niche:
- The outcome phrase lives in the app name only, where it reads as a name.
- **No sentence anywhere asserts a mechanism.** Never say the pulse is
  acupressure or stimulates anything. Learn says the opposite, deliberately.
- "Feelings of nausea", not "nausea". Verbs are "support", "designed to", "try".
- Where a claim is unavoidable, quote the source's own hedge ("may improve").
- Never compare Queasy to Sea-Band or Reliefband on price or effect. Both are
  FDA-cleared Class II devices; claiming their function without their clearance
  is the 1.1.6 finding in its purest form, and under EU MDR an intended purpose
  of "alleviation of disease" makes software a medical device. The Regulated
  Medical Device declaration on this app is **No** and copy must stay consistent
  with that.

**Pregnancy** is back, in the product and the description, and stays out of the
name, subtitle, keywords and screenshots. Naming an occasion is not a claim;
promising an outcome for it is what was rejected. Morning sickness carries a
gentler intensity cap, a longer session, and a call-your-midwife note.

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing, review funnel, gotchas):
always-loaded global CLAUDE.md + the `ios-dev` skill. (TestFlight needs the ASC app record to exist first.)

## Subagent delegation
Follow the global CLAUDE.md subagent rules: ask Jack for the model before spawning, spawn at most one at a time unless Jack explicitly approves more, and never allow a subagent to spawn another subagent.
