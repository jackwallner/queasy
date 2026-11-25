# State machine audit, 2026-11-24

Scope: the Queasy iPhone app and the phone side of the Watch bridge, audited from committed code at `63f2bff` (the fleet snapshot of Jack's working tree). The Watch app's own engine (`WatchHapticEngine`) was read only where the phone depends on it. Android is out of scope. No app code was changed for this phase.

**Summary: 0 bugs proved by failing test, 3 code path only (not proved).** Plus 8 product calls (not counted).

Evidence run: `gh-sim test --scheme Queasy --only QueasyTests/StateMachineAuditRepro` on a clean checkout of `63f2bff` with only the repro file added, run `queasy-start-imac1c09-1124-172931-15491`, GitHub run `45526131832` (Xcode 27.1, iPhone 17, iOS 27.2): 2 tests, 0 passed, 2 failed, and both failed in setup, not on a claim. Laying the reminders threw `UNErrorDomain 2003 "Repository could not save notification. Source is not authorized." (UNAuthorizationStatus=Denied)`: the CI simulator refuses to hold a notification request without permission, so neither the claim nor its control reached an assertion. That run proves nothing about B1, which therefore stays code path. The repro suite is `state-machines-2026-11-24-repro.swift` beside this file (copy it into `QueasyTests/` to run it). The test bundle compiles `Shared/` as well, so the suite spells app types `Queasy.` (the `WatchLauncherTests` convention); otherwise it would drive the bundle's own copy of `SubscriptionService`.

Seams used: `SubscriptionService.setLocalOverride(isPro:)` (the DEBUG entitlement hook), the real `RootView` and `SettingsView` hosted in a `UIWindow` on the app host's scene, and `UNUserNotificationCenter` on the app host. Seams that do not exist: a constructible RevenueCat `CustomerInfo` or purchase result (RevenueCat is not injected), and notification permission (a headless simulator cannot answer the prompt, so reminders are laid with the same identifiers `schedule()` uses rather than through `setEnabled(true)`). That is why the Ask to Buy and resubscribe items stay code path, and, as the run showed, why B1 does too: the simulator will not hold the requests at all without permission.

## Bugs ranked by impact

| ID | Bug | What the user sees | Promise | User route | Impact | Evidence | file:line |
|---|---|---|---|---|---|---|---|
| B1 | Press reminders outlive Pro | A subscriber who turned on Press reminders lets Pro lapse. The three daily nudges (8 AM, 2 PM, 8 PM) keep arriving, a Pro feature they no longer have, until they happen to open the Settings tab in a later launch. A lapse noticed while the app is running never stops them in that process, even if Settings was already open. | `SettingsView.swift:160-161`: "Reminders are a Pro feature, so a lapsed subscription stops them". `PressReminderService.swift:68-69`: "Pro lapsed: reminders are a Pro feature, so they stop". `FreeTier.swift` lists `pressReminders` as a Pro feature. | Pro: Settings, Press reminders on. Cancel the subscription in iOS Settings and let the period end. Open Queasy: it starts on Relieve (`RootTabView.initialTab` is 0) with the cached Pro flag, RevenueCat's refresh then reports no entitlement (`SubscriptionService.applyProStatus`). Use Relieve, History, Learn; do not open Settings. The reminders keep firing. The only stop is `SettingsView`'s `.task` (`SettingsView.swift:159-166`), which runs once, when the Settings tab first appears. | Every lapsed subscriber who had reminders on, any device or locale, every day until they visit Settings in a fresh launch. Morning-sickness users are the ones the reminders are pitched at (`PressReminderService.hours` comment), so this lands on the group most likely to have them on. Cost: three notifications a day for a feature they are not paying for, which reads as broken or as being billed. | Not proved. The repro (`lapsingWhileTheAppRunsStopsThePressReminders`, control `controlOpeningSettingsWhileNotProStopsThePressReminders`) could not lay its precondition requests on the CI simulator (see the evidence run above). Code read: nothing but `SettingsView`'s `.task` calls `suspendForNonSubscriber`, and nothing observes `isProSubscriber` to call it again. | `SettingsView.swift:159-166`; `PressReminderService.swift:68-72`; no observer of `isProSubscriber` anywhere else |
| C1 | (Code path, not proved) A resubscribe leaves the reminders toggle on with nothing scheduled | A lapsed user opens Settings (the `.task` suspends the reminders but keeps the preference, so the toggle still reads on), taps See Queasy Pro and buys. Back on Settings the toggle is on and the footer says "A nudge at 8 AM, 2 PM, 8 PM", but no reminder is scheduled until a later launch reaches Settings again. | `SettingsView.swift:161`: "the stored preference stays so resubscribing restores it". | Settings (lapsed, reminders preference on), See Queasy Pro, buy. Settings is already mounted, so its `.task` does not run again. | Lapsed users who resubscribe from Settings in the same launch. Rare, and it heals on a later launch that visits Settings. | Not run: proving it needs `refresh()` to see an authorized notification permission, which a headless simulator cannot grant. The B1 fix (reconcile on every Pro change) covers this path too. | `SettingsView.swift:159-166`, `PressReminderService.swift:54-65` |
| C2 | (Code path, not proved here) Ask to Buy reads as a failed purchase | A child in Family Sharing taps the trial button and asks a parent. The paywall shows "Purchase didn't complete. Please try again." in coral, inviting a second request, although the request went through. | `PaywallView.swift:691-692` holds a calm pending message ("Purchase is pending approval. Queasy Pro unlocks as soon as it's approved."), and `PurchaseState.pending` exists for it. | Settings, See Queasy Pro, Start My 7-Day Free Trial, Apple's sheet, Ask. RevenueCat throws `ErrorCode.paymentPendingError` for a deferred purchase, which the paywall's `catch` turns into the failure line (`PaywallView.swift:696-697`); the pending message is only reached when a purchase returns without throwing and without an entitlement. | Family Sharing child accounts with Ask to Buy. Rare, but the copy tells them to do it again. | The paywall's handling is inline view code with no seam on the starting commit. Rollout A (same day, `81e838e`) maps the SDK error to the pending message; `PurchaseFailureTests` prove the mapping against the SDK's own error codes. Not counted here. | `PaywallView.swift:683-699`, `SubscriptionService.swift:342-362` |

## Product calls (not counted: documented, or no cited promise)

1. `PressReminderService.refresh()` switches the stored preference off when iOS notification permission is off (`PressReminderService.swift:59-63`). Turning notifications back on in iOS Settings does not bring the reminders back; the user has to find the toggle again. The fleet rule is to restore rather than switch a toggle off, but what the toggle should show while iOS blocks notifications is a product call. The footer "Turn them on in iOS Settings to use reminders" only shows after a tap on the toggle, never after this path.
2. Unknown intro-offer eligibility reads as not eligible (`SubscriptionService.isEligibleForIntroOffer`, documented), so a failed eligibility lookup shows "Start Queasy Pro" with no trial wording.
3. Products come from the `default` offering (`fetchProducts`), not `current`. A RevenueCat Experiment whose variant changes packages would not change what the paywall sells. The new metadata reader reads `current`, so wording tests work; package tests would not.
4. `PhoneSessionController` counts down on a 1-second `Timer`. A phone locked mid-session pauses the clock and Core Haptics, and resumes where it stopped on return. No copy promises background play on the phone (the Watch path is the background one).
5. `completedSessionCount` counts a skipped rating on the phone (`PhoneSessionView.saveEpisode`) but not on the watch-remote path (`WatchRemoteSessionView.saveEpisode` returns before counting). It feeds the upgrade milestones (3, 8, 20), so the after-session paywall lands a session earlier or later depending on where people rate.
6. `ReviewPromptTracker.markShown()` runs before `requestReview()` and starts the 30-day cooldown even when iOS shows nothing. Documented as pacing.
7. A History row deleted on the phone can come back if the Watch's queued unrated copy of the same session arrives after the delete (`QueasySyncService.persistEpisode` inserts when the UUID is missing). Needs a delete inside the WatchConnectivity delivery window; no copy promises deletes survive.
8. `ConversionDiagnostics.recordConversion` runs only on a direct purchase result. An Ask to Buy approved later through the delegate, or a restore, never writes the `converted_*` attributes. Affects Jack's attribution only.

## State machines

### SM1. Entitlement and purchase (`SubscriptionService`)

State: `isConfigured`, `isProSubscriber` plus its App Group cache (`isProSubscriber` key), `products`, `isLoadingProducts`, `lastError`, `introEligibility`, `paywallImpressionsThisSession`.

States: Unconfigured (simulator without the Test Store key) / Configured, cached / Free / Pro / Pending (a purchase that returned without an entitlement, or Ask to Buy).

Invariants: E1 `isProSubscriber` equals "any active entitlement" after every `applyProStatus`; E2 a failed refresh keeps the last state (`refresh()` swallows errors); E3 the trial is promised only when RevenueCat confirmed eligibility; E4 anything that is Pro-only follows E1 (broken by B1).

| From | Event | To | Invariant |
|---|---|---|---|
| Unconfigured | `configure()` on a device | Configured, cached (`isProSubscriber` from the App Group) | none |
| Configured, cached | `refresh()` ok | Free or Pro | E1 |
| Configured, cached | `refresh()` throws (offline) | unchanged | E2 |
| Free | purchase ok with entitlement | Pro, conversion recorded | E1 |
| Free | purchase returns without entitlement | Pending, "pending approval" message | none |
| Free | Ask to Buy (`paymentPendingError` thrown) | Free, failure line shown | C2 |
| Pending | delegate delivers entitlement | Pro, paywall closes on `onChange(isProSubscriber)` | E1 |
| Pro | delegate or refresh finds the entitlement gone | Free | E1 holds; E4 broken (B1) |
| any | restore ok | Pro or Free with "No active Queasy Pro purchase found" | none |

### SM2. Press reminders (`PressReminderService`)

State: stored `pressRemindersEnabled`, `authorizationDenied` (memory only), the three repeating requests `queasy.press.reminder.{8,14,20}`, iOS permission, and Pro (SM1).

Invariants: N1 requests are pending only while Pro and the preference is on and iOS allows them; N2 a lapse keeps the preference (so a resubscribe restores it); N3 the toggle reads the stored preference.

| From | Event | To | Invariant |
|---|---|---|---|
| Off | toggle on, Pro, permission granted | On, three requests | N1 |
| Off | toggle on, not Pro | paywall, Off | N1 |
| Off | toggle on, permission refused | Off, `authorizationDenied` | N1 |
| On | toggle off | Off, requests removed | N1 |
| On | Settings `.task`, Pro, permission off in iOS | Off (preference cleared) | product call 1 |
| On | Settings `.task`, not Pro | On (preference kept), requests removed | N1, N2 |
| On, requests pending | Pro lapses, Settings not opened in this launch (or already open) | requests stay pending | N1 broken (B1) |
| On, suspended | resubscribe while Settings is mounted | requests stay missing until a later launch visits Settings | N1 broken (C1) |

### SM3. Paywall presentation and purchase UI

State: `RootTabView.showUpgrade`, `UpgradePromptCoordinator.pendingImpressionId`, `ReliefPanel.paywall` (Duo pane), `SettingsView.showPaywall`, and the paywall's own `@State` (`selectedPackage`, `isPurchasing`, `isRestoring`, `errorMessage`, `restoreMessage`).

Invariants: P1 the purchase button never stays spinning (`defer { isPurchasing = false }`); P2 a Pro customer never sees the paywall stay up (`onChange(isProSubscriber)` closes it); P3 the after-session paywall and the rating ask never follow the same session; P4 the coordinator clears on dismiss.

| From | Event | To | Invariant |
|---|---|---|---|
| idle | capped session at a milestone (3, 8, 20), 5-day cooldown | `pendingImpressionId` set, sheet 600 ms later | P3 |
| sheet | dismiss | `pendingImpressionId` cleared | P4 |
| sheet | purchase ok | closes | P2 |
| sheet | purchase pending or failed | stays, message shown, button idle | P1 |

No invalid transition found. The pending and error messages are view `@State`, so nothing outlives the sheet.

### SM4. Review ask (`ReviewPromptTracker`, `RootTabView`)

State: `appLaunchCount`, `lastShownDate` (and the legacy `lastReviewPromptAt`), `outcome`, `hasPendingPositiveMoment`, `ReviewPromptCoordinator.momentCount`, `RootTabView.reviewTask`.

Invariants: R1 no ask before the 2nd cold launch or before onboarding; R2 30 days between calls; R3 opening the review page ends the asks and feedback never does; R4 never over a presentation; R5 a blocked ask keeps the moment pending.

| From | Event | To | Invariant |
|---|---|---|---|
| idle | session saved not rated worse, no upgrade offered | pending, `momentCount` bumped | R1 checked at ask time |
| pending | 3 s later, clear | shown (`markShown`, `requestReview`) | R2, R4 |
| pending | 3 s later, something up | pending | R5 |
| any | Settings, Rate Queasy | `openedWriteReview` | R3 |
| any | Settings, Send Feedback | `submittedFeedback`, asks continue | R3 |

The tracker holds (covered by `ReviewPromptTrackerTests`). What counts as the moment ("not rated worse" includes "The same" and Skip) is the Rollout S question, handled there.

### SM5. Phone session (`PhoneSessionController`)

State: `phase` (idle, running, rating), `plan`, `intensity`, `startedAt`, `remainingSeconds`, `sessionUUID`, the episode upserted by UUID.

Invariants: S1 a running session that ends is saved before the rating (so a killed app keeps it); S2 the rating updates that same row; S3 a cancel under 60 s leaves no row.

| From | Event | To | Invariant |
|---|---|---|---|
| idle | `start` | running, new UUID | none |
| running | clock reaches 0 or I'm Done | rating, row saved unrated | S1 |
| rating | Better / The same / Worse / Skip | idle, row updated | S2 |
| running | cancel under 60 s | idle, no row | S3 |
| running | cancel at 60 s or more | idle, unrated row | S1 |
| running | app suspended | clock and haptics pause, resume on return | product call 4 |

No invalid transition found.

### SM6. Watch-remote session and episode sync (`WatchSessionMirror`, `QueasySyncService`)

State: mirror `phase` (idle, running, ended), `pendingAutoPresent`, the snapshot, and episodes arriving by `transferUserInfo`.

Invariants: W1 one row per session UUID whichever side writes first; W2 a later unrated copy never clears a rating (`if let severityAfter`); W3 the phone's rating tells the Watch to drop its own rating screen.

All three hold on read (`QueasySyncService.persistEpisode`, `WatchRemoteSessionView.saveEpisode`). Deletes are the gap (product call 7).

### SM7. First run (`hasCompletedOnboarding`, `phoneOnlyAcknowledged`)

Onboarding hands straight to the tabs with no paywall; the review ask checks `hasCompletedOnboarding` (R1). No invalid transition found.
