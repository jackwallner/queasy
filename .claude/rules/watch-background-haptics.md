---
paths:
  - "QueasyWatch/Services/WatchHapticEngine.swift"
  - "QueasyWatch/QueasyWatchApp.swift"
  - "QueasyWatch/Views/WatchSessionView.swift"
  - "QueasyWatch/Info.plist"
  - "QueasyWatch/QueasyWatch.entitlements"
  - "Queasy/Services/WatchLauncher.swift"
  - "Queasy/Queasy.entitlements"
  - "Shared/Services/QueasySyncService.swift"
  - "project.yml"
  - "Queasy/Views/WatchRemoteSessionView.swift"
---

# Queasy: Watch background haptics

Moved verbatim from CLAUDE.md. Loads when a matching file is read; update it here.

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
