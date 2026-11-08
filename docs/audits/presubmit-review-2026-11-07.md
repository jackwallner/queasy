# Queasy 1.1.7 pre-submit review (2026-11-07)

Scope: app sources changed since the live 1.1.6 (`4217ad0`, the 1.1.6 version
commit; builds 37 and 38 changed no app code) to `origin/main` at `bc36238`
(1.1.7, build 41). Tests, docs, fastlane, qa and `android/` excluded.

The change set is two things:

1. The bug-hunt fixes committed after build 38: the Tone renders at the output
   sample rate (`ToneGenerator`), the History heatmap keeps every day across a
   DST midnight skip (`EpisodeStats`), and `WatchLauncher` caps a free session's
   length before it reaches the watch.
2. The localization refactor: every user-facing string routed through
   `Shared/Localizable.xcstrings` (en plus id, ja, nl, pt-BR, ru, th, vi,
   zh-Hans), `PluralLabel`, `DisplayFormat`, `storedCatalogKey`/`displayTips`,
   whole-sentence trial copy in `SubscriptionService`, and a Language row in
   Settings.

## What was checked

- Crashes and data loss: no new force unwraps on data, no SwiftData model or
  Codable shape change (`ReliefPlan.displayTips` is computed; stored tips stay
  English and old saved plans decode as before). `EpisodeStats` loop always
  advances. `ToneGenerator` detaches its node on start failure and on stop.
- Localization lookups: every catalog key with a format specifier matches the
  Swift interpolation types (all interpolated counts are `Int`, so `%lld`;
  prices and clocks are `String`, so `%@`). `python3 Tools/Localization/check.py`:
  377 keys, 8 languages, 0 problems. `"%lld plural category"` carries the CLDR
  categories each language needs (ru one/few/many/other, ja/zh/th/vi/id other).
- Stored values stay unlocalized: no localized `title`, `label` or display name
  feeds sync payloads, the CSV, sorting or analytics (`queasyAnalyticsPlan`
  replaces the old lowercased display name).
- Purchases: offering lookup, restore, trial eligibility (still defaults to not
  eligible until RevenueCat confirms), trial copy now chosen by period unit, and
  `trialEndTitle` reads the trial's day count instead of matching "7" in text.
  Paywall keeps Terms of Use and Privacy Policy links and real StoreKit prices.
- App Review: the mock plan cards with hard-coded prices and the Debug section
  are `#if DEBUG` only. The disclaimer keeps "not a medical device / does not
  diagnose, treat or cure" in all eight translations (spot-checked), and the Pro
  feature titles carry no outcome claims in translation.

## Findings

| Severity | File:line | What happens | Status |
|---|---|---|---|
| P2 | QueasyWatch/Views/WatchHomeView.swift:17 | A Pulse or Breathe session started on the Watch itself, with no plan pushed from the phone, uses `ReliefPlan.quickStart` (15 min) or the watch's last plan, so a free user gets past the 2-minute free cap on the wrist. The 1.1.7 `WatchLauncher` fix only caps plans the phone sends. Predates 1.1.6. | Not fixed: the watch has no purchase state, so closing it means syncing entitlement over WatchConnectivity, a design change too large for a pre-submit pass. Not a crash or a review risk. |

No P0 or P1 findings in the 1.1.6 to 1.1.7 diff.

## Tests

`gh-sim test --scheme Queasy` on `bc36238` (no code changed by this review):
run `queasy@20261108-063020-8900-claude-mbpro3d566-1108-064652-31004`, Xcode
27.1, iPhone 17 on iOS 27.2, 96 passed, 0 failed, 0 skipped.
