---
paths:
  - "android/**"
  - "scripts/android-*"
  - "scripts/sync-android-*"
  - "scripts/make-play-*"
---

# Queasy Android rules

## Product

- Native port in `android/`: Kotlin, Compose, Gradle Kotlin DSL, JDK 17,
  minSdk 26, target/compile 36. Package and namespace `com.jackwallner.queasy`
  (permanent once uploaded), launcher label "Queasy", Play title
  "Trip Comfort: Motion Sickness" (the live App Store name). versionName
  follows iOS `MARKETING_VERSION` (1.1.4), versionCode 1 (bump before every upload).
- Screen for screen with iOS: onboarding (4 pages, no paywall) > tabs Relieve /
  History / Learn / Settings; mode sheet, 3-question check-in > recommendation,
  full-screen session with the per-mode stage, 3-choice rating, paywall.
  Sheets are an overlay stack in `AppGraph.Navigator`; back leaves a running
  session going and the Relieve card reopens it.
- Model and engine are a straight port of `Shared/Models` and
  `PatternEngine.swift`. `scripts/sync-android-parity.sh` compiles the Swift
  sources with `scripts/android-export/main.swift` into
  `app/src/test/resources/queasy-parity.json`; `PortParityTest` checks all
  1,080 check-in plans, 64 free-tier caps, the pulse table, breathing
  patterns, causes, copy and Pro features. Rerun it whenever those Swift files change.
- Intentional differences from iOS, all because Android has no Watch app:
  no watch gate/send-to-watch/watch pulse cap; Breathe tagline and blurb say
  "phone"; the Pro length bullet drops "on your wrist with the screen off";
  Learn's "How to wear your watch" is "How to hold your phone"; onboarding
  page 4 explains the phone's vibration. Play In-App Review with no question
  first (Settings has separate Rate and Send Feedback rows); Play cancellation
  wording; Terms link to the site's terms.html, not Apple's EULA.
- Haptics: `HapticPatterns` turns `PulseSpec` and `BreathePattern` into
  `VibrationEffect` waveforms (swell on amplitude-control motors, start-of-phase
  taps on on/off motors), `USAGE_MEDIA`. Tone: a looping static `AudioTrack` of
  whole 100 Hz cycles at iOS amplitude 0.18. The screen stays on during a session.
- Paid boundary = iOS: free Pulse/Breathe cap at 120 s, Tone/Press never
  capped, free History shows 7 days (older rows behind Pro), Press reminders
  are Pro (AlarmManager `setWindow` at 8/14/20, re-armed on delivery and boot).
  Note iOS also leaves the rhythm and length pickers ungated although
  `ProFeature.ownRhythm` lists them; the port matches iOS.
- Billing: RevenueCat project `proj2744fe37` (shared with iOS). Debug uses the
  Test Store app `appeb637c4dc1` (key in ignored `local.properties`
  `REVENUECAT_TEST_KEY`), offering `default`, entitlement lookup key
  "Queasy Pro"; any active entitlement unlocks Pro, as on iOS. Release uses
  the `goog_` key of RevenueCat Play app `app95e75d7057` (created 2026-10-21)
  in the Air's `local.properties` `REVENUECAT_PLAY_KEY`.
- Reviewer access: Settings > About > long-press Version. The release build
  embeds the digest of the Air's `QUEASY_PLAY_REVIEW_CODE` (`~/.queasy_credentials`,
  2026-10-21); give Play's App access form that code, not jmbp's older
  `PLAY_REVIEW_CODE`.
- Debug launch extras (debug only, `src/debug/.../DebugLaunchOptions.kt`):
  `uiTest`, `resetAll`, `onboarded`, `demoPro`, `previewStore`,
  `previewTrialUsed`, `seedDemo`, `heatmap`, `launchCount`, `learnCard <id>`,
  `tab history|learn|settings`, `screen mode-<m>|session-<m>|checkin|recommend-<cause>|paywall`.

## Build and test (fleet Pro, jmbp)

- `JAVA_HOME=~/jdks/temurin-17/Contents/Home ./gradlew clean assembleDebug assembleDebugAndroidTest assembleQa lintDebug testDebugUnitTest`
  from `android/`. Lint has 0 errors; remaining warnings are dependency bumps
  and the needed `mipmap-anydpi-v26` folder.
- Connected tests: boot a leased AVD headless (`emulator -avd agent-emu-1
  -port 5556 -no-window -no-audio -no-boot-anim -no-metrics -gpu host -cores 3
  -no-snapshot-save`), then `ANDROID_SERIAL=emulator-5556
  scripts/android-connected-tests.sh [--no-build]`. It runs each UI Automator
  test with `pm clear` between, passes the reviewer code as an
  instrumentation argument, writes
  `android/app/build/outputs/androidTest-results/connected/TEST-queasy-smoke.xml`,
  and fails on any failure or a zero count. Stop the AVD with
  `adb -s emulator-5556 emu kill`. Never touch `small_phone` or another agent's device.
- jmbp is an Intel i7-5557U: emulator motion records at about 7 fps, so native
  60 fps cannot be proven there. Motion review belongs on faster hardware.

## Release state (2026-10-21)

- Build and test acceptance done on jmbp (run shift-android-queasy-3-1792543160):
  99 JVM tests, 12 device tests, lint clean, QA build ignores debug hooks.
- Signed release packaged and verified on the Air (run
  shift-android-package-queasy-2-1792592980, source 326ed8b, android tree
  2bb524b, identical to `main`): `queasy-1.1.4-vc1.aab` (sha256 59422e75...)
  and `.apk` (e5a58cc6...) in
  `~/fleet-artifacts/shift-android-package-queasy-2-1792592980/`. Package
  `com.jackwallner.queasy`, versionCode 1, versionName 1.1.4, targetSdk 36,
  not debuggable. APK v2 signature and AAB jarsigner both match upload key
  `~/.android/keystores/queasy-upload.p12` alias `upload` (cert SHA-256
  13a34c54b70cb6a69c422d137cf69e17d1c638e6d4dffc6a7962e548280c0316; backup in
  `keystores/backups`). zipalign -P 16 passes; the only native library,
  `libandroidx.graphics.path.so`, has 16 KB ELF alignment on all four ABIs
  and is stored uncompressed. Release dex holds the `goog_` key and the review
  digest, and no Test Store key, plain review code or debug-extra string.
  Evidence (`release-preflight`, `build`, `signature-verify`) in
  `~/fleet-evidence/shift-android-package-queasy-2-1792592980/`. Rebuild:
  `JAVA_HOME=<temurin-17> ./gradlew --no-daemon assembleRelease bundleRelease`
  from `android/` with the Air's `local.properties` (the guard permits it),
  then rerun that run's `verify.py`.
- `~/.rc-clean/apps.json` now has the queasy android block (2026-10-21).
- Play state 2026-10-21: nothing uploaded, no track, nothing staged or in
  review. RevenueCat Play app `app95e75d7057` has no products attached.
- Remaining, in order (Air release worker / Console):
  1. Decide the Android US price (fleet rule $2.39 / $11.99 / $23.99, or iOS parity).
  2. Create the Play app (E3 Apps) if it does not exist, and the three products
     with `trial-7d` offers.
  3. Attach the Play products to the RevenueCat Play app, the `default`
     offering packages and the "Queasy Pro" entitlement.
  4. Listing, graphics and policy answers from `android/play-assets/listing-en-US.md`;
     publish the updated `privacy-policy.html`.
  5. Upload `queasy-1.1.4-vc1.aab` to internal testing (bump versionCode for any
     later upload), licensed-tester purchase and restore, then a production
     draft. Production send waits for its pacing slot.
- Not ported, decision for Jack: a Wear OS companion (the iOS Watch app's
  extended-runtime background haptics). v1 is phone-only.
