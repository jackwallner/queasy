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
  "Queasy Pro"; any active entitlement unlocks Pro, as on iOS. Release needs a
  `goog_` key: no RevenueCat Play app exists yet.
- Reviewer access: Settings > About > long-press Version, code
  `PLAY_REVIEW_CODE` in `~/.queasy_credentials` (created on jmbp 2026-10-20;
  copy it and `PLAY_REVIEW_CODE_SHA256` to the Air before the release build).
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

## Release state (2026-10-23)

- Build and test acceptance done on jmbp (run shift-android-queasy-3-1792543160):
  99 JVM tests, 12 device tests, lint clean, QA build ignores debug hooks.
- Done 2026-10-21: upload keystore `~/.android/keystores/queasy-upload.p12`
  (backup in `~/.android/keystores/backups`, password in `~/.queasy_credentials`),
  RevenueCat Play app in `proj2744fe37`, `goog_`/`test_` keys, `PLAY_UPLOAD_*`
  and the review code hash in `local.properties` on the Air, rc-clean
  registered on the Air and MBP, listing graphics and screenshots made.
- Signed release artifacts (Air only, built 2026-10-21, re-verified 2026-10-23
  by run shift-android-package-queasy-4-1792775526, evidence in
  `~/fleet-evidence/<run>/`), in
  `~/fleet-artifacts/shift-android-package-queasy-2-1792592980/`:
  `queasy-1.1.4-vc1.aab` (sha256 59422e75...1e45) and `queasy-1.1.4-vc1.apk`
  (sha256 e5a58cc6...d8f1). Built from 326ed8b, `android/` tree 2bb524b.
  com.jackwallner.queasy, versionCode 1, 1.1.4, minSdk 26, targetSdk 36,
  upload cert SHA-256 13a34c54...0316 (APK v2, AAB jarsigner), 16 KB zip and
  ELF alignment, no debug launch hooks, `goog_` key and review digest only.
  main's later `android/` change (8b89b82, Test Store QA user id) only acts on
  `test_` keys, so release behaviour is the same; a rebuild from main gives new
  bytes and needs the same verification.
- Play state: nothing uploaded, no app record, no track, nothing staged or in review.
- Remaining, in order (Air release worker / Console):
  1. Jack: the Android US price (fleet rule $2.39 / $11.99 / $23.99, or iOS parity).
  2. Play app record (E3 Apps). Play hit its weekly new-app limit on 2026-10-21;
     retry the next week. The name matches the App Store name.
  3. The three products with `trial-7d` offers, attached to the `default`
     offering packages; grant the RevenueCat service account on the new app.
  4. Listing, graphics and policy answers from
     `android/play-assets/listing-en-US.md`; publish the updated `privacy-policy.html`.
  5. Upload the AAB above to the internal track, licensed-tester purchase and
     restore, then a production draft. Production send waits for its pacing slot.
- Not ported, decision for Jack: a Wear OS companion (the iOS Watch app's
  extended-runtime background haptics). v1 is phone-only.
