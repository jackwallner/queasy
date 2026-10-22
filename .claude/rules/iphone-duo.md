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
  (Relieve, Learn, Settings, tab bar included) on the leading side of the fold
  and History on the trailing side; the History tab drops out of the bar while
  split. Pane edges come from `GeometryProxy.verticalFold()` (iOS 27.1
  `reservedRegions(.division, .includeInactive)`), else an even split. Every
  compact width, and the unfolded display in portrait (669 pt), keep the four
  tabs.
- `UnfoldedSplitView` is one view tree: the primary pane is never rebuilt on
  fold/unfold, so Relieve, Learn and Settings keep scroll, navigation and
  presentations. Only the History pane and tab are separate instances. Each
  pane gets `horizontalSizeClass = .compact`, which keeps the phone layout and
  the bottom tab bar.
- A mode's detail and the check-in (`ReliefPanel`) open as a sheet on a
  phone and in the trailing pane when split, over History, beside the grid
  they came from; a centred form sheet straddles the fold (iter1 capture).
  Their Close/Cancel calls `ReliefPanel.shared.close()`, not `dismiss`.
  Paywall sheets use `.foldAwareSheet`, which becomes a full-screen cover
  inside an unfolded pane (`isUnfoldedPane`), with the paywall in the
  leading pane.
- Phone and watch-remote sessions (full-screen covers) use the same split: the
  routine before the fold, History after it. Onboarding and the full-screen
  paywall use `.leadingPaneColumn()` before their background.
- Same pattern as Vitals (`jackwallner/vitals`, `Shared/Utilities/UnfoldedSplit.swift`).
- Captures: one `gh-sim all --device 'iPhone Duo'` run with
  `-QueasyScreenshots -QueasyProOverride -QueasySeedDemoData -DuoTour` and
  `noop://N` URLs as shutter ticks shoots both displays; `DuoTour` walks the
  scenes on a timer and logs `DUOTOUR` lines. Never drive captures by custom
  URL scheme (the "Open in?" alert cannot be tapped). Inner 2853x2007
  landscape, outer 1398x2034.
