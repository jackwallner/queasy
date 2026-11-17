# Pre-submit review: Queasy 1.1.7 (deep pass, 2026-11-08)

Live version 1.1.6 (last commit `a3efa6c`, build 38). Reviewed HEAD `bc36238`
(1.1.7, build 41) on `origin/main`: the diff since 1.1.6 (mostly the
localization move to `Shared/Localizable.xcstrings`, the watch free cap in
`WatchLauncher`, the tone sample-rate fix, the heatmap DST fix) and every path a
user can reach: onboarding, Relieve, check-in, mode start, phone and watch
sessions, ratings, History, Settings, paywall, purchase and restore, Press
reminders, SwiftData store and migration, WatchConnectivity sync, iPhone Duo
split, localization. No widgets or App Intents exist.

Checked and clean: `ReliefEpisode` schema unchanged since 1.1.6; `ReliefPlan`
decodes older payloads (hand-rolled `init(from:)`); store quarantine instead of
delete on open failure; RevenueCat offering lookup (`default`, else current),
yearly default selection, intro eligibility defaulting to not eligible, any
active entitlement counts as Pro, paywall closes on Pro, Restore, Terms and
Privacy in every paywall state; no prices hard-coded outside the DEBUG
screenshot mock; debug UI and launch arguments are `#if DEBUG`; no links to
other platforms; disclaimers say not a medical device and no treat, cure or
diagnose claims. `python3 Tools/Localization/check.py`: 377 keys, 8 languages,
0 problems.

## Findings

| Severity | File:line | What happens | Status |
|---|---|---|---|
| P1 | `Queasy/Views/RelieveHomeView.swift:422`, `Queasy/Views/ModeStartView.swift:193` | A free user's "Start on Apple Watch" saved the 2-minute free cap into `lastPlan`. After buying Pro, quick start still ran 2 minutes ("Level 5 · 2 min"). For free users the next quick start no longer counted as capped, so the after-session Pro offer and the length note never appeared. `WatchLauncher` already caps what it sends. | Fixed: the saved plan keeps its full length, and `ReliefPlan.quickStart(resuming:)` raises a stored Pulse or Breathe length under the engine floor back up (tests `QuickStartPlanTests`). |
| P1 | `Queasy/Views/RelieveHomeView.swift:32` | Quick start ignored the Settings session length and breath pace (mode cards and the check-in apply them through `resolvedPlan`). A Pro user who chose 30 minutes got 15 from the main button. | Fixed: quick start goes through `resolvedPlan`, in the same commit. |
| P1 | `Queasy/Views/WatchRemoteSessionView.swift:131` | The phone's controls for a wrist Breathe session always drew a 4 in, 6 out bloom, whatever pace the watch was tapping (3/5 when mild, 4/8 when severe, or the Settings pace). | Fixed: the watch state carries the pace, older watches read as the default (tests `WatchStateSnapshotTests`). |
| P1 | `Queasy/Views/SettingsView.swift:215` | Restore Purchases in Settings said "No purchases found." when the restore actually failed (offline), telling a paying user they own nothing. | Fixed: shows the service's error, as the paywall does. No unit test (view code). |
| P2 | `Queasy/Views/SettingsView.swift:33` | Session length and Breath pace are open to free users, while `ProFeature.ownRhythm` sells "set the breathing rhythm ... and save the one that suits you as your default". A Pro feature is unlocked for free. | Not fixed: gating is a product decision. |
| P2 | `QueasyWatch/Views/WatchHomeView.swift:16` | The watch has no purchase state, so a free user who never sent a plan from the phone can run the default 15-minute session from the watch's own quick start. | Not fixed: needs purchase state on the watch; by design today. |
| P2 | `Queasy/Views/SettingsView.swift:55` | After Pro lapses, reminders are cancelled but the toggle still reads on, and turning it off opens the paywall. Reminders are only re-laid from the Settings tab, though `PressReminderService.swift:55` says on launch. | Not fixed: cosmetic, no duplicate or missing notifications for a Pro user. |
| P2 | `Queasy/Views/CheckInView.swift:339` | The recommendation's `.task` saves `lastPlan` and logs check-in completed when the page is first built. A paged TabView can build it before both context answers are in, and the task has no id, so it does not re-run. Starting a session saves the right plan anyway. | Not fixed: plausible only, no user-visible effect proven. |
| P2 | `Queasy/Views/LearnView.swift:41` | Learn says Queasy suggests 4 in, 8 out "when they are not" mild; the engine uses 4/6 for severity 3 and 4 and 4/8 only at 5. A 1.1.6-style "says it does what it does not" risk, minor. | Not fixed: copy change across 9 languages. |
| P2 | `Queasy/Views/LearnView.swift:54` | A source link is titled "Nagoya University: a unique sound alleviates motion sickness" (the press release headline), an outcome phrase without the paper's "may". | Not fixed: copy and claims tone are out of scope; flag for `docs/positioning.md`. |
| P2 | `.claude/rules/watch-background-haptics.md` | Describes an `HKWorkoutSession` remote launch through `HKHealthStore.startWatchApp`; the code has only the extended runtime session and the queued WatchConnectivity handoff. | Not fixed: docs only, no app impact. |

## Verification

- `python3 Tools/Localization/check.py`: 0 problems.
- `swiftc -typecheck` of `ReliefPlan`, `ReliefMode`, `PatternEngine`, `FreeTier`: clean.
- Unit tests on GitHub's Macs with `gh-sim test --scheme Queasy --only QueasyTests`: see the commit that adds this report for the run id and result.
