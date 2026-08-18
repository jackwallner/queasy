> NOTE (2026-07-14): pregnancy positioning is dead — App Review rejected it
> twice under 1.1.6. Pregnancy mode, keyword, Learn card, and screenshot copy
> are removed. Historical notes below predate that.

# Queasy — Product Scope (v1)

Decided 2026-07-01 with Jack.

## The product

Software anti-nausea band. Open the app → answer 3 quick questions (what's causing
it, how bad, still exposed?) → get a recommended vibration pattern → your Apple
Watch plays it against your wrist until you feel better. Rate how you feel after;
history shows what actually works for you.

Positioning: **general nausea app** (decision: general, not pregnancy-first).
Modes: motion sickness (car/boat/plane/VR), pregnancy/morning sickness, hangover,
vertigo/dizziness, anxiety, general/illness.

## Decisions

| Question | Decision |
|---|---|
| Hardware | Watch-first + iPhone Core Haptics fallback ("hold phone to your inner wrist") |
| Positioning | General nausea app; pregnancy is one mode |
| Monetization | $4.99/mo, $29.99/yr (both with 1-wk trial), $69.99 lifetime (bumped 2026-07-02 to match Headache Tracker's live tier), hard paywall after onboarding, RevenueCat |
| Name | **Queasy: Nausea Relief Band** — chosen from ASO research (see aso-plan.md) |
| Bundle IDs | com.jackwallner.queasy (+ .watch), App Group group.com.jackwallner.queasy |

## Why this is winnable (competitor research, 2026-07-01, US store)

- **Sense Relief** (Watch vibration, the direct comp): 3.4★, 38 ratings, ranks #1
  "nausea relief" / #2 "anti nausea". Weak and old. Reviews complain about
  reliability. Beatable on quality alone.
- **Dizzout** (3.7★, 3 ratings), **RideCalm** (16 ratings), **Carsick.App** (2.6★) —
  a fresh wave of tiny apps, none with a real Watch haptic product.
- A 2025 "100 Hz sound therapy" trend spawned several sound-only apps
  (MotionSicknessTone, HearEase, Hearapy, Not Dizzy — all <20 ratings). Queasy
  includes a 100 Hz tone mode too, so we cover both modalities in one app.
- SERPs for "motion sickness" / "car sickness" are so thin that games and photo
  editors leak into the top 10 → low keyword walls.
- "queasy" SERP has zero direct competitors → clean brand + exact-match token.
- Hardware anchors the price story: Reliefband devices are $100-250; Sea-Bands are
  disposable elastic. "$19.99/yr instead of a $175 gadget" is the paywall frame.

## How the relief works (and how we talk about it)

Reliefband/EmeTerm stimulate the P6 (Nei-Kuan) point on the inner wrist;
Sea-Bands press it. Clinical evidence for P6 stimulation on nausea is mixed but
real (Cochrane-reviewed for PONV). A Watch vibrating on the wrist is NOT medical
nerve stimulation — copy must stay in "complementary comfort technique" land
(App Review 1.4.1): rhythmic pulses + guided wear position (turn the watch to the
inner wrist, two finger-widths below the crease) + breathing pacing. Never
"treats/cures", always "may help ease".

## v1 feature list

**iOS app**
1. Onboarding (3 pages: promise → how it works/wear position → modes) + disclaimer
2. Hard paywall (RevenueCat; monthly/yearly-trial/lifetime)
3. Check-in: cause grid → severity 1-5 → "still exposed?" toggle → recommendation
4. Recommendation screen: intensity level (1-10), duration, pattern preview
   animation; actions: Start on Watch / Use iPhone instead
5. Phone session: looping Core Haptics pattern, live intensity +/- , pulse
   animation, screen kept awake, optional 100 Hz tone layer (headphones advised)
6. After-session: "feeling better?" → severity-after → saved ReliefEpisode
7. History: episodes list + stats (avg severity drop, sessions this week, best
   mode); relief-delta is the retention hook
8. Learn: P6 explainer, wear position diagrams, per-cause tips, science + medical
   disclaimer
9. Settings: default duration, watch pulse strength cap, restore purchases, rate,
   privacy/EULA links, debug pro toggle

**Watch app** (standalone-capable)
1. Home: pending plan from phone (or quick-start last plan / default level 5)
2. Session: WKExtendedRuntimeSession (physical-therapy) + timed haptic pulses,
   intensity +/- during session, remaining time, End
3. After: Better / Same / Worse → episode syncs back to phone
4. Watch complication: deferred to v1.1

**Engine** (pure, unit-tested)
- `PatternEngine.recommend(for: CheckIn) -> ReliefPlan`
- base intensity = severity×2, +1 if still exposed, pregnancy capped at 7 and
  softened, clamped 1-10; duration 8+severity×3 min (pregnancy/hangover +5, cap 45)
- 10-level pulse table: interval 2.4s→0.5s, burst 1→3, strength soft→strong
- Watch mapping: soft=.click, medium=.directionUp, strong=.notification
- iPhone mapping: Core Haptics transients, intensity .5/.75/1.0

## Explicitly out of v1

Widgets/complications, notifications/reminders, HealthKit, CloudKit sync,
localized in-app strings (App Store metadata IS localized), Android, iPad.

## Launch state (2026-07-03)

Done: ASC app record 6786780495 (version 1.0, all 50 locale metadata +
screenshots uploaded, categories, age rating, review detail), subscriptions +
lifetime IAP with worldwide prices at the bumped tier ($4.99/mo, $29.99/yr,
$69.99 lifetime — USA base + equalized in 175 territories, matching Headache
Tracker's live pricing), 1-week free trial on BOTH subs, IAP review
screenshots showing the current-price paywall, RevenueCat fully wired, pages
live at jackwallner.github.io/queasy/ (support + pricing + EULA/privacy
links), TestFlight build 6 uploaded and attached to 1.0.

App Store screenshots are the watch-first set (watch-bezel hero "The
anti-nausea band you already own" → one-tap relief → pattern → modes →
queasy-log heatmap → drug-free/price anchor). All 50 locale descriptions
carry Terms of Use (Apple standard EULA) + privacy links (3.1.2) and
price-generic subscription copy. en keywords carry `wristband`. App Privacy
labels published by Jack. Export compliance declared, internal TestFlight
group "Jack" gets builds automatically.

Remaining: Jack device-tests build 6 (sandbox purchase both trials at the new
prices, watch install-lag flow, onboarding watch gate) and presses Submit.

Remaining before Jack presses Submit:
1. App Privacy labels in ASC UI (no public API): App Privacy → Get Started →
   "Purchases" → Purchase History → App Functionality → NOT linked to user →
   not used for tracking → Publish. Everything else: not collected.
2. Test build 2 on device (paywall purchase via sandbox, watch session with
   wrist down). IAPs in Ready to Submit ride along with the first version
   review automatically; verify they appear in the submission sheet.

Post-launch: replace Astro temp app id 114 with 6786780495; PPP territory
pricing pass (same flow as Sober/Gist/SimpleGLP).
