# Queasy Android port: report (run shift-android-queasy-3-1792543160, jmbp)

Task `android-queasy`, 2026-10-20. Branch `fleet/shift-android-queasy-1-1792538047`,
final source commit in `source-commit.txt`. Prior runs 1 and 2 died on usage
limits before writing anything, so this run built the port from scratch.

## Result

Native Kotlin/Compose port in `android/`, package `com.jackwallner.queasy`,
screen for screen with iOS 1.1.4: four-page onboarding with no paywall, Relieve
(quick start, check-in, four mode cards), mode sheets, the three-question
check-in and recommendation, the full-screen session (ripple, breathing bloom,
tone disc, press hold ring) with live level control and the optional 100 Hz
layer, the three-choice rating, History (stats, heatmap, CSV export,
long-press delete, 7-day free window), Learn (six topics, sources), Settings
(length, rhythm, Press reminders, heatmap, Pro, restore, rate, feedback,
privacy, terms, reviewer code) and the RevenueCat paywall.

Engineering acceptance met on this host. Play release work has not started
(no Play app, keystore, RevenueCat Play app or products exist).

## Verification (fleet-proof records in this folder)

| Check | Command | Result |
|---|---|---|
| Build + lint | `./gradlew clean assembleDebug assembleDebugAndroidTest assembleQa lintDebug` (JDK 17, from `android/`) | pass, lint 0 errors |
| JVM tests | `./gradlew testDebugUnitTest` | 99 tests, 0 failures |
| Device tests | `ANDROID_SERIAL=emulator-5556 scripts/android-connected-tests.sh --no-build` on agent-emu-1 (API 36 Play image) | 12 tests, 0 failures |

- `PortParityTest` reads a fixture exported from the real Swift sources
  (`scripts/sync-android-parity.sh`): all 1,080 check-in plans (6 causes x 9
  severities incl. out-of-range x exposed x ate x 5 mode choices), 64 free-tier
  cap cases, pulse table, breathing patterns, causes, feelings, Press steps,
  Pro features and copy. Intended Android copy differences are asserted, not ignored.
- Device tests cover first run without a paywall, check-in ranking (Tone first
  for motion, level 9, 20 min capped to 2 free), free cap opening the paywall
  with trial disclosure, Pro full length, session > rating > History, live
  level control, free vs Pro History window, Press reminders gated to Pro,
  Play reviewer code (wrong code rejected, right code unlocks), the live
  RevenueCat Test Store offering loading over the network, and Learn.
- One run of the network test timed out at 45 s: a cold RevenueCat start on
  this emulator took 41 s to return Test Store products (SDK request ordering
  plus the slow host; the plans did load). Timeout raised to 120 s; the
  recorded run passes 12/12. The test change does not touch app source, so the
  build/unit records (taken one commit earlier) cover the shipped code.
- QA build (R8, debug-signed, no store key): launch extras `onboarded`,
  `demoPro`, `screen` are ignored (stays on onboarding, `qa-hooks-ignored.png`);
  onboarding > quick-start Pulse > I'm Done > Better > History ran with no
  crash (`qa-session.png`, `qa-history.png`).

## Screens inspected

`screenshots/`: onboarding, Relieve, recommendation (motion), Breathe session,
Press sheet, History (free, seeded), Pro History, Learn, Settings, paywall
(preview store), Pulse session. Fixed from inspection: Nunito/Newsreader are
variable fonts and rendered too light until each weight got an axis setting;
the tab bar stayed in the accessibility tree and took stray touches under
sheets; switch off-track used Material's lilac instead of the Tide palette.

## Motion

`video/checkin-breathe.mp4` records a real task (check-in > Breathe session >
rating > History) with `fleet-record60.py`: 0 flicker or jump events, but 7.2
fps in motion windows. jmbp is an Intel i7-5557U emulator host (Quit Zyn
measured about 16 fps here), so native 60 fps is not proven and cannot be on
this machine. Blocker for the motion check: rerun the capture on faster
hardware (the Air motion task). No frames were interpolated.

## Platform gap (decision for Jack)

The iOS Watch app (extended-runtime background haptics, phone-to-watch launch)
has no Android counterpart in v1. The port is phone-only; every "your watch"
line was rewritten for the phone and the Pro length bullet no longer promises
"on your wrist with the screen off". A Wear OS companion is a separate
decision, not guessed at here.

## Paid boundary note (iOS finding)

`ProFeature.ownRhythm` ("Pick your own rhythm and level") is listed as Pro, but
iOS leaves the Settings rhythm and length pickers free. The port matches iOS
exactly; if the bullet should be true, gate the pickers on both platforms or
drop the bullet.

## Release preparation done

- `android/play-assets/`: listing text (title 29, short 79, full 2,036 chars,
  no prices or em dashes, claims per `docs/positioning.md`), 512 icon, 1024 x
  500 feature graphic (`scripts/make-play-feature-graphic.swift`), six 1080 x
  1920 free-state screenshots, policy and Data safety answers
  (`listing-en-US.md`).
- `privacy-policy.html`: Android section (Google Play billing, notification
  permission only for reminders, no Health Connect). Not published (no push).
- Reviewer code created in jmbp `~/.queasy_credentials` (`PLAY_REVIEW_CODE`
  and its SHA-256); only the digest is in the ignored `local.properties`.
- `.claude/rules/android.md` (paths `android/**`) indexed from `AGENTS.md`.

## Remaining Play / Console steps (in order)

1. Jack: Android US price. Fleet rule is about 20% under iOS
   ($2.39 / $11.99 / $23.99); iOS is $2.99 / $14.99 / $29.99, already cut.
2. Air: copy `PLAY_REVIEW_CODE` / `PLAY_REVIEW_CODE_SHA256` from jmbp
   `~/.queasy_credentials`; create `~/.android/keystores/queasy-upload.p12`
   and `PLAY_UPLOAD_*`; build and verify the signed AAB/APK (package,
   versionCode 1, targetSdk 36, 16 KB alignment).
3. Play Console (E3 Apps): create the app, the three products with `trial-7d`
   offers, listing, graphics, App content forms, internal track upload.
4. RevenueCat `proj2744fe37`: add a Play app, attach the Play products to the
   `default` offering packages and the "Queasy Pro" entitlement, put its
   `goog_` key in `local.properties`, and register it in `~/.rc-clean/apps.json`
   the same day (android block plus `"ios": {"filter_platform": "iOS"}`).
5. Licensed-tester purchase and restore on the internal track, then a
   production draft. The production send waits for its pacing slot.

## Update 2026-10-21: signed release packaged

Run shift-android-package-queasy-2-1792592980 built and verified the signed
AAB and APK on the Air (versionCode 1, 1.1.4, targetSdk 36, upload key cert
13a34c54..., 16 KB aligned, debug hooks absent). Steps 2 and the RevenueCat
Play app part of 4 are done; artifacts, hashes and evidence paths are in
`.claude/rules/android.md`. Nothing is uploaded to Play yet.

## Housekeeping

Emulator emulator-5556 (agent-emu-1) stopped; Gradle daemon stopped;
`small_phone` and the networked TM15 device were not touched.
