# Fixes for the 2026-11-24 state machine audit

**Summary: 3 claims, all code path (none proved on the starting commit). 2 fixed, 1 fixed under Rollout A, 0 held, 0 skipped.**

## Skeptical review

Each claim, re-read as an outside reviewer would:

- **B1 survives.** The route is reachable: the app opens on Relieve (`RootTabView.initialTab` is 0), a `TabView` builds the Settings tab only when it is first selected, and Settings' `.task` was the only caller of `suspendForNonSubscriber`. Nothing else observed `isProSubscriber`. It is still not proved on the starting commit: the CI simulator refused to hold the precondition requests (`UNErrorDomain 2003`, permission Denied), so the repro never reached an assertion.
- **C1 survives as code path.** Settings stays mounted once visited, so its `.task` does not run after a purchase. Proving it needs `refresh()` to see a granted permission, which a headless simulator cannot provide.
- **C2 survives.** RevenueCat throws `ErrorCode.paymentPendingError` for a deferred (Ask to Buy) purchase, and the paywall's `catch` showed the failure line. Rollout A is the fix.

No claim was dropped. None is counted as proved.

## Claims

| ID | Outcome | Commit | Regression test | What changed |
|---|---|---|---|---|
| B1 | Fixed (code path; the code read is unambiguous and the promise is quoted) | `fix(reminders): stop Press reminders when Pro lapses, restore them on resubscribe` | `StateMachineRegressionTests/lapsingWhileTheAppRunsStopsThePressReminders`, control `controlOpeningSettingsWhileNotProStopsThePressReminders`, upgrade check `aLapseKeepsTheStoredReminderPreference` | `RootView` reconciles the reminder schedule after `configure()` on launch and on every change to `isProSubscriber` (`PressReminderService.reconcile(isPro:)`: refresh when Pro, suspend when not). Settings' `.task` calls the same method. A `removeRequests` closure seam (the `WatchLauncher.send` pattern) lets the test record the cancel, because the CI simulator will not hold real requests. The lapse test hosts the real `RootView` and flips Pro with the DEBUG override; with the `onChange` removed nothing observes the flip, so it records no removal. |
| C1 | Fixed by the B1 change (code path, no test) | same commit | none: a resubscribe re-lays the schedule only when iOS permission is granted, which a headless simulator cannot grant | The `onChange(isProSubscriber)` that suspends on a lapse also calls `refresh()` when Pro returns, so a purchase or restore re-lays the reminders the user had on. |
| C2 | Fixed under Rollout A | `fix(paywall): Ask to Buy says it is waiting for approval` | `PurchaseFailureTests` | See `rollout-2026-11-24.md`. |

Stored data: nothing changes shape. The stored `pressRemindersEnabled` preference is never cleared by a lapse (`aLapseKeepsTheStoredReminderPreference`), so an existing user who had reminders on gets them back on resubscribe. At launch the reconcile reads the cached Pro flag; a wrong cache only cancels or re-lays requests (never the preference) and is corrected by the next RevenueCat update through the same `onChange`.

## Held for Jack

None from the claims. The product calls in `state-machines-2026-11-24.md` were not acted on; the first one (iOS notification permission switched off turns the stored reminder preference off, and permission granted later does not bring it back) is the one worth a decision.

## Skipped

None.

## Tests

The regression tests were not run against a revert of the fix: the GitHub Mac queue had already cost 45 minutes for one targeted run, so the one run spent goes to the full suite on the fixed branch (see `rollout-2026-11-24.md`). To check the failing half, remove the `onChange(of: subscriptions.isProSubscriber)` in `Queasy/App.swift` and run `gh-sim test --scheme Queasy --only QueasyTests/StateMachineRegressionTests`; the lapse test should fail and the two others pass.
