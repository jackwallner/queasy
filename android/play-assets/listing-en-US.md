# Queasy: Google Play listing (en-US)

Source of truth for the Play Console store listing, adapted from
`fastlane/metadata/en-US/` for Android: no Watch app (the phone's own vibration
plays Pulse and Breathe), Google Play billing and cancellation wording, no
prices in copy (Play shows them), no em dashes. Read `docs/positioning.md`
first: the subject of every sentence is the user, never the app acting on the
body, and pregnancy stays out of the title and short description.

## Listing text

`metadata/android/en-US/` (fastlane supply layout):

- `title.txt` "Trip Comfort: Motion Sickness" (29/30), the live App Store name.
- `short_description.txt` (79/80).
- `full_description.txt` (2,036/4,000).

The launcher label stays "Queasy", as on iOS.

## Graphics

- `icon-512.png` 512 x 512, no alpha, from the iOS `AppIcon.png` (`sips -z 512 512`).
- `feature-graphic.png` 1024 x 500, no alpha, `swift scripts/make-play-feature-graphic.swift .`
- `screenshots/` six 1080 x 1920 PNGs (no alpha): raw 1080 x 2400 debug captures
  from `agent-emu-1` on jmbp (status bar in demo mode, 09:41) scaled onto the
  seafoam canvas. Free state only: no test unlock, no paywall. Raw captures in `raw/`.
  The App Store headline compositor was not run (no PIL on jmbp); swap in
  headline frames on the Air if wanted.

## Products (to create in Play Console)

| Play product | Type | Base plan / offer | RevenueCat package |
|---|---|---|---|
| `com.jackwallner.queasy.pro.monthly` | Subscription | base plan `monthly` (P1M), offer `trial-7d` (P1W free, new customers) | `$rc_monthly` |
| `com.jackwallner.queasy.pro.yearly` | Subscription | base plan `yearly` (P1Y), offer `trial-7d` (P1W free, new customers) | `$rc_annual` |
| `com.jackwallner.queasy.pro.lifetime` | One-time product | buy option `lifetime` | `$rc_lifetime` |

iOS US prices are $2.99 / $14.99 / $29.99 with a 1-week trial on both
subscriptions. The fleet rule sets the Android ladder about 20% under iOS
($2.39 / $11.99 / $23.99); Queasy's iOS ladder was already cut on 2026-08-14,
so the Android US price is a decision for Jack (see the Android rule). iOS
prices, the `Queasy Pro` entitlement and the `default` offering are untouched.

## Policy answers (from the code)

- Ads: none. App access: everything without an account. Reviewer access to
  Queasy Pro: Settings > About, long-press Version, enter the code
  (`PLAY_REVIEW_CODE` in `~/.queasy_credentials`), tap Unlock. Only its SHA-256
  ships in the build (`PLAY_REVIEW_CODE_SHA256` in ignored `local.properties`).
- Target audience: 18+ (the check-in names pregnancy, hangover).
- Content rating: no violence, sexuality, gambling, user content or location;
  mentions of alcohol (hangover) as a reason for feeling sick.
- Health apps declaration: general wellness / symptom-comfort techniques with
  cited sources. Not a medical device (consistent with the iOS Regulated
  Medical Device declaration of No). No Health Connect access.
- Data Safety: collected by the RevenueCat SDK only. Financial info > Purchase
  history; App activity > App interactions (paywall view counts, app-open
  count, conversion surface, as subscriber attributes); Device or other IDs
  (RevenueCat's anonymous app user ID, not a hardware or advertising ID).
  Purposes: app functionality and analytics. Encrypted in transit. Not shared
  (RevenueCat is a service provider). Not optional. Deletion by email request.
  Check-ins, sessions, ratings and settings never leave the device.
- Permissions: `INTERNET` (RevenueCat), `VIBRATE` (sessions),
  `POST_NOTIFICATIONS` (asked only when Press reminders are turned on, Pro),
  `RECEIVE_BOOT_COMPLETED` (re-arm reminders). No exact alarms, no foreground
  service, no location, camera, microphone or Health Connect.
- Privacy policy: https://jackwallner.github.io/queasy/privacy-policy.html
  (Android section added 2026-10-20; publish with the next site push).
- Contact: jackwallner+q@gmail.com. Website: https://jackwallner.github.io/queasy/
