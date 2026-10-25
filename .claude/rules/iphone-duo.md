---
paths:
  - "Queasy/Views/UnfoldedSplit.swift"
  - "Queasy/Views/RootTabView.swift"
  - "Queasy/Views/PhoneSessionView.swift"
  - "Queasy/Views/WatchRemoteSessionView.swift"
  - "Queasy/Views/DuoTour.swift"
---

# Queasy: iPhone Duo (2026-10-21)

- Unfolded (regular width, at least 720 pt), `RootTabView` puts the TabView
  (Relieve, Learn, Settings) on the leading side of the fold and History on
  the trailing side; History drops out of the tabs while split. Pane edges
  come from `GeometryProxy.verticalFold()` (iOS 27.1
  `reservedRegions(.division, .includeInactive)`), else an even split. Every
  compact width, and the unfolded display in portrait (669 pt), keep the four
  tabs.
- `UnfoldedSplitView` is one view tree: the primary pane is never rebuilt on
  fold/unfold, so Relieve, Learn and Settings keep scroll, navigation and
  presentations. Only the History pane and tab are separate instances. Each
  pane gets `horizontalSizeClass = .compact`, which keeps the phone layout.
- Split, the system tab bar is hidden (`.paneTab(isSplit)`) and the tabs
  (`PaneTabStrip`, from `\.paneTabs`) take the title's place in the leading
  pane's navigation bar (`paneNavigationTitle`), level with History's title
  across the fold, like the iPad's top tab bar. The system bar was a vertical
  bar beside the fold after a folded launch and a glass capsule over the
  pane's last rows after an unfolded one (review 2026-10-23: rows sliced
  under it, "About" under it, crammed under the session's I'm Done). A
  leading-edge rail (tried in run 6, all-1) cost Relieve 72 pt of width.
- iOS 27.1 put the inner display's status bar and History's toolbar in a
  column on the trailing edge (about 85 pt), so History was narrower than
  Relieve and its share button sat outside the pane. The History pane opts
  out (`horizontalBarsInPane()`, `toolbarVerticalBehavior(.disabled)`): the
  status bar runs along the top and the share button sits in History's own
  bar. Apply it only there.
- `.paneTab` sets `.toolbar(.hidden, for: .tabBar)` from a background layer
  on the tab root (outside its NavigationStack; the same modifier inside the
  stack, from a background, did nothing). It hides the bar while split and,
  for Relieve, while a session is up (`ReliefPanel.sessionIsUp`).
  OPEN REGRESSION (run 6, 2026-10-23): with `.paneTab` in any form the
  folded session's full-screen cover shows the outer display's vertical tab
  bar beside it; `75a1438` (no `.paneTab`) does not, on the same runner.
  Hiding from the tab root while the session is up does not help, so the
  next step is to remove `.paneTab` and hide the split's bar without
  touching folded tab roots. Bisect with a launch-only
  `--screen "-QueasyScreen session-breathe"` run. The in-pane session hides
  the navigation bar background and the iOS 26 top scroll edge effect,
  which drew a tinted band under the tabs.
- A mode's detail and the check-in (`ReliefPanel`) open as a sheet on a
  phone and in the trailing pane when split, over History, beside the grid
  they came from; a centred form sheet straddles the fold (iter1 capture).
  Their Close/Cancel calls `ReliefPanel.shared.close()`, not `dismiss`.
  Paywalls use `.paywallSheet`: a sheet on a phone, and when split the
  trailing pane (`ReliefPanel.paywall`, over the panel), so Relieve and the
  tab bar stay before the fold and no half of the display is blank. Both Duo
  displays are 669 to 678 pt tall, shorter than the paywall, whose renewal
  terms ran off the screen edge there: the paywall drops its trial timeline
  (or feature list) first, keeping plans, button, terms and links whole, and
  scrolls only if that is still too tall. The session rating steps use
  `View.scrollsWhenTall()`.
- Phone and watch-remote sessions are full-screen covers on a phone. When
  split they are an overlay on Relieve's scroll view inside its navigation
  stack, so the tabs stay in the bar above the session (not under its
  buttons) and History after the fold: one navigation on every surface (an
  earlier review flagged the session that hid it). Their close buttons call `closePane` when it is set (`dismiss`
  otherwise). Onboarding and the `-QueasyPaywallScreenshot` paywall use
  `.leadingPaneColumn()` before their background.
- History rows put the date and the details ("Level 8 · Watch") on separate
  one-line rows; the trailing pane is about 370 pt of content and one long
  line broke values like "18 min" across lines. Settings says "Breath pace"
  because "Breathing rhythm" beside "Match my symptoms" wrapped the picker.
- Same pattern as Vitals (`jackwallner/vitals`, `Shared/Utilities/UnfoldedSplit.swift`).
- Captures: one `gh-sim all --device 'iPhone Duo'` run, base `--args
  "-QueasyScreenshots -QueasyProOverride -QueasySeedDemoData"`, one
  `--screen` per surface: `"-QueasyTab relieve"`, `"-QueasyScreen session-breathe"`,
  `"-QueasyTab learn"`, `"-QueasyTab settings"`, `"-QueasyScreen
  mode-breathe"`, `"-QueasyScreen checkin"`, `"-QueasyScreen upgrade"`.
  Never use `--url` (custom schemes raise an "Open in?" alert; `noop://`
  ticks are banned). `-DuoTour` (timed scene walk, `DUOTOUR` log lines) is
  for video only. Inner 2853x2007 landscape, outer 1398x2034. Screenshot
  runs show the paywall's static plan cards (RevenueCat never loads there).
- Video: `gh-sim all --record-seconds` loses the launch recordings (the
  test-phase recorder never releases the display). Record with a separate
  `gh-sim launch --record-seconds 40`. The inner video comes back
  2006x2852, the panel's native portrait framebuffer; do not rotate it.
  On 2026-10-23 the same command returned only 5.5 s (inner) and 9.7 s
  (outer) of a 40 s request; check durations before relying on it.
