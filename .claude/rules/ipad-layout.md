---
paths:
  - "Queasy/Views/ReadableColumn.swift"
  - "Queasy/Views/RelieveHomeView.swift"
  - "Queasy/Views/OnboardingView.swift"
  - "Queasy/Views/PhoneSessionView.swift"
  - "Queasy/Views/UnfoldedSplit.swift"
  - "Queasy/Info.plist"
  - "project.yml"
---

# Queasy: iPad layout (added 2026-11-12)

- `TARGETED_DEVICE_FAMILY "1,2"` on the app target only; the watch is untouched.
  `UISupportedInterfaceOrientations~ipad` lists all four orientations, so there
  is no `UIRequiresFullScreen`.
- An iPad has no haptic engine and cannot pair a watch. `ReliefMode.available`
  drops Pulse there (card, quick start, check-in picker); `onThisDevice` maps a
  saved Pulse plan to Breathe. Breathe on iPad is the on-screen circle only
  (`cardTagline`, `detailBlurb`, session guidance have iPad strings). Tone and
  Press run as on iPhone. Onboarding skips the two watch pages, ends on
  "Get Started" and sets `phoneOnlyAcknowledged`. Never offer a mode that plays
  nothing here: it is a 1.1.6 finding waiting to happen.
- The Duo split (`UnfoldedSplitView`) is off on iPad (`!DeviceIdiom.isPad`).
  An 820 pt iPad would otherwise cut itself into two phone-width panes. Sheets
  stay system form sheets.
- `readableColumn(_:)` caps a screen's content at 600 pt (560 for onboarding,
  paywall and sessions) and centres it; it does nothing on a phone. Put it
  inside the scroll view so the scroll bar stays at the screen edge.
- Relieve is two columns from 1100 pt wide (landscape only; start card and
  check-in beside the mode list, 1060 pt cap), one 600 pt column below that.
  A short single column floats a little above centre (`CenteringScrollView`). Mode cards are
  full-width rows on iPad because three modes in a two-up grid leave a hole.
- Session stage is 340 pt on iPad (240 on iPhone).
- Captures: nothing in the app can rotate a headless iPad (`requestGeometryUpdate`
  and the orientation KVC are ignored). `QueasyUITests/IPadCaptureUITests` turns
  the device with `XCUIDevice` and attaches each screen; run it with
  `gh-sim test --scheme QueasyUITests --device 'iPad Pro 13-inch (M5)' --only
  QueasyUITests/IPadCaptureUITests` (about 15 min, 20 frames, files in
  `~/.gh-sim/results/<id>/attachments/`, named in `manifest.json`). Landscape
  frames arrive as 2064x2752 with the layout turned 90 degrees: `sips -r 90`
  makes them 2752x2064 upright. Onboarding needs `-QueasyResetOnboarding`
  without `-QueasyScreenshots`. ASC wants 2064x2752.
