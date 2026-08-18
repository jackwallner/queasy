# Queasy: positioning and rebuild plan

Written 2026-08-14. Supersedes the positioning sections of `aso-plan.md` and
`scope.md`. Research basis: App Store SERPs and Astro popularity data pulled
2026-08-14, verbatim competitor listings via the iTunes lookup API, the current
App Review Guidelines, EU MDR/MDCG guidance, and the clinical literature on P6
stimulation, paced breathing, and the 100 Hz tone.

---

## 1. What actually happened, decoded

Queasy 1.0 was rejected twice under **guideline 1.1.6**, citing "calming
vibration pulses to relief nausea in pregnancy", with Apple adding that a
disclaimer does not cure misleading app plus metadata. The app then shipped
de-claimed as `Queasy: Wrist Comfort Aid` / `For Queasy Moments`, which is the
current live 1.0.1.

The guideline number is the whole story, and it was misread at the time.

- **1.4.1** is "medical apps get more scrutiny". It is survivable with
  disclaimers, citations, and a see-your-doctor prompt. That is the guideline
  the app was defended against (the review notes, the layered disclaimers).
- **1.1.6** is *false information and features*, the same rule used against fake
  location trackers. Apple was not saying "you need a better disclaimer". Apple
  was saying **the feature does not do what you claim it does**, and 1.1.6
  explicitly cannot be cured by caveats.

That reading is uncomfortable but largely correct on the facts. The clinical
evidence for P6 is for *sustained pressure* (a band with a stud) or *electrical*
stimulation (Reliefband, which is FDA-cleared). There is no trial of an Apple
Watch haptic buzz at P6, and even for real pressure the Cochrane review of
interventions for nausea and vomiting in early pregnancy calls the P6 evidence
"limited" and inconsistent. So "vibration = acupressure = nausea relief" was an
unsupported mechanism claim, and pregnancy raised it to a vulnerable-population
claim.

**Consequence for the rebuild:** the fix is not softer wording around the same
feature. The fix is to build features whose claims are true, and let the copy
describe them plainly.

---

## 2. The market, measured

Astro US iPhone, pulled 2026-08-14. The popularity scale floors at 5, and 5
means no measurable volume. Calibration from the rest of the fleet:
`calorie tracker` 74, `calorie counter` 65.

**Terms with real volume that Queasy can honestly serve:**

| Keyword | Pop | Diff | Note |
|---|---|---|---|
| apple watch | 73 | 59 | Queasy is a genuine Watch-first app |
| watch app | 45 | 60 | same |
| breathing exercises | 30 | 61 | the Breathe mode maps straight onto it |
| dizzy | 26 | 45 | |
| wrist | 20 | 13 | cheap |
| motion sickness | 14 | 5 | free win, the only symptom term with volume |
| breathing | 9 | 59 | |

**Walls (real demand, unwinnable):**

| Keyword | Pop | Diff |
|---|---|---|
| pregnancy tracker | 67 | 78 (BabyCenter has 294,950 ratings) |
| pregnancy | 55 | 78 |
| cruise | 52 | 73 |

**Dead, all at popularity 5:** nausea (diff 56), nausea relief (5, we rank 69),
morning sickness (52), morning sickness relief (70), morning sickness tracker
(68), pregnancy nausea (68), motion sickness relief (5, we rank 154), car
sickness (43), sea sickness (41), travel sickness (39), boat sickness (58),
airplane sickness (72), vertigo (5), vertigo relief (5, we rank 158), hangover
(9), hangover cure (11), sea band (23), wristband (7, we rank 243), acid reflux
(9), panic attack (21), vr motion sickness (52).

Three conclusions, and they set everything else in this document.

**a. The whole symptom vocabulary is dead, not just ours.** `panic attack` and
`acid reflux` are also popularity 5. People do not search the App Store by
symptom. They search by product category (`calorie tracker`, `pregnancy
tracker`, `breathing exercises`) and by device (`apple watch`).

**b. The nausea niche specifically is a desert.** `nausea relief` has difficulty
5, meaning it is nearly free to rank first, and it is worth almost nothing.
Sense Relief has held #1 on it since 2019 and has accumulated **38 ratings in
seven years**. That is the ceiling of an organic-search strategy here.

**c. Pregnancy demand is real but unreachable by keyword.** The volume sits on
`pregnancy` (55) and `pregnancy tracker` (67) at difficulty 78, against
megabrands. `morning sickness` itself is popularity 5.

So: **putting pregnancy back in App Store metadata buys popularity-5 traffic and
re-opens the exact claim that got the app rejected twice.** That is a bad trade
before risk appetite even enters. Pregnancy is a *product and channel* decision,
not an ASO one.

And the searchable framing for this app is not "nausea relief band" at all. It
is **Apple Watch (73) plus breathing exercises (30) plus motion sickness (14)
plus dizzy (26)**, with `nausea relief` taken for free at difficulty 5. The
Breathe mode is both the most defensible feature and the only one that maps to a
term with meaningful search volume, which is a convenient convergence.

---

## 3. What competitors say, and what that precedent is worth

Verbatim from live listings, with last-update dates, because the date is the
part that matters.

**Sense Relief** (id 1457764420, Medical, free, no IAP, 3.4 stars / 38 ratings,
**last updated 2022-03-24**):

> "Sense Relief App™ uses acupressure to quickly and effectively relieve your
> nausea and vomiting associated with morning sickness and motion sickness."
> ... "Studies have found that up to 75% of patients treated with P6 acupressure
> gained relief from morning sickness symptoms."

Subtitle: `Ease Nausea & Morning Sickness`. It ranks #1 for both `nausea relief`
and `morning sickness`.

This is the app Jack is thinking of when he says others get away with it. The
catch: **its metadata has not been through review since March 2022.** App Store
listings are only re-reviewed when a version is submitted. It is grandfathered,
not permitted. It is not a precedent a new submission can rely on, and its
seven-year haul of 38 ratings shows the prize is small anyway.

Recently approved apps in the same space, which *are* live precedent:

| App | Updated | What it gets away with | Category |
|---|---|---|---|
| Dizzout | 2026-08-07 | Name is literally "Stop Motion Sickness"; body copy hedges ("designed to support you", "help reduce feelings of nausea") | Travel |
| NoMo | 2026-08-14 | "eliminating discomfort instantly", "science-backed" | Utilities |
| Hearapy | 2026-07-11 | "stop motion sickness before it starts", "scientifically-backed 100Hz" | Health & Fitness |
| AntiSick | 2026-08-09 | Feature-descriptive throughout, explicit "not intended to diagnose, prevent, treat, or cure" | Health & Fitness |
| Motion Ease | 2025-04-29 | "may potentially act as an auditory anchor to help ease that discomfort" | Medical |

Three patterns worth copying:

1. **A strong noun phrase in the app *name* still passes.** "Stop Motion
   Sickness" cleared review a week ago. Naming the condition is not the problem.
2. **Every survivor with a bold claim points at a citable study.** The 100 Hz
   apps all lean on one paper: Gu, Ohgami, Kagawa et al., *"Just 1-min exposure
   to a pure tone at 100 Hz with daily exposable sound pressure levels **may
   improve** motion sickness"*, Environmental Health and Preventive Medicine,
   2025-03-25, DOI 10.1265/ehpm.24-00247. Note the hedge is in the title of the
   paper itself. This is exactly what 1.4.1 asks for: disclosed data and
   methodology behind the claim.
3. **The boldest claims sit outside the health categories.** Dizzout is Travel,
   NoMo is Utilities, Carsick.App is Productivity. Health & Fitness and Medical
   draw the strict reviewers.

Nobody currently sells morning-sickness relief on a 2025-or-later approval.
There is no fresh precedent for it. That absence is data.

---

## 4. The regulatory floor, which is not Apple's opinion

Two things constrain claims independently of any reviewer's mood.

**EU MDR 2017/745.** Software whose *intended purpose* includes "treatment or
alleviation of disease" is a medical device (MDCG 2019-11 applies this directly
to phone apps). Recital 19 exempts "software intended for life-style and
well-being purposes". So "relieves nausea" as a stated intended purpose is a
Class I medical device claim in the EEA and UK, requiring CE marking. "A guided
comfort routine you run yourself" is not.

**Apple's new Regulated Medical Device declaration.** Since 2026, any app with
Health & Fitness or Medical as a primary or secondary category must declare
regulated-device status before it can be submitted. Queasy was declared **No**
on 2026-07-22. Answering No is the correct and only viable answer, and it is a
formal statement that the app makes no diagnosis or treatment claim. Metadata
that contradicts it is the definition of a 1.1.6 finding.

**Also in scope: the marketing site.** Guideline 2.3.1 covers "marketing your
app in a misleading way ... whether within or outside of the App Store". The
plan below puts pregnancy on the website, so this matters: the site may name the
audience, but it may not make a claim the app metadata cannot.

### Why "the App Store equivalent of a nausea relief band" needs splitting in two

Both bands are **FDA-cleared Class II medical devices**, and that is the
entire reason they may say what they say.

- **Sea-Band**: elastic band with a plastic stud pressing P6. Cleared 510(k),
  substantially equivalent to pre-amendment acupressure devices, indicated for
  relief of nausea in motion sickness, morning sickness, and chemotherapy or
  anesthesia-induced nausea.
- **Reliefband**: Class II neuromodulation device, median nerve stimulation,
  $100 to $250, cleared for nausea and vomiting from motion sickness, migraine,
  hangover, anxiety, morning sickness, chemotherapy and post-op.

Sea-Band's box can say "relief of nausea in morning sickness" because it holds
clearance for that indication. An app saying the same sentence is asserting a
cleared indication it does not hold. Guideline 1.4.1 says so almost in as many
words: "If your medical app has received regulatory clearance, please submit a
link to that documentation with your app." That is why review reached for 1.1.6
rather than 1.4.1. They read the app as claiming a cleared device's function
without the device or the clearance.

So Queasy can be the band's equivalent in **occasion and vibe**, and it can be
the band's **coach**, but it cannot be its equivalent **in claim**. Which points
at the strongest honest version of the idea: most people wear a Sea-Band in the
wrong place. Queasy is the app that puts it in the right place, times the hold,
and reminds them the way the trials dosed it.

### The bright lines

The rule that separates every approved competitor listing from Queasy's rejected
one is the **subject of the sentence**. If the app or the watch is the subject
and the verb acts on the body, it is a 1.1.6 risk. If the user is the subject
and the app is the instrument, it is fine.

| Not OK | OK |
|---|---|
| "Vibration delivers acupressure" / "stimulates the P6 nerve" | "Taps a steady rhythm on the inside of your wrist" |
| "Relieves nausea in pregnancy", "stops morning sickness" | "For car, boat, plane and queasy days" (Dizzout's *name* is "Stop Motion Sickness", approved 2026-08-07) |
| "Instead of a $175 Reliefband" | "A drug-free technique you can run anywhere" |
| "75% of users get relief" | "A 2025 Nagoya University study found 1 minute at 100 Hz **may improve** motion-sickness measures" (the paper's own hedge) |
| Implying the app performs the therapy | Teaching the user a technique and timing it for them |
| Any outcome promise on a condition | Any amount of symptom logging, trigger patterns, history |

Note what is *not* on the bad list: the words "nausea" and "relief" themselves.
`Queasy: Nausea Relief Kit` is a category name, not a mechanism claim. What
killed 1.0 was the mechanism and the promise, not the vocabulary.

---

## 5. Recommended positioning

**Queasy is a kit of drug-free comfort routines you run on your wrist when you
feel sick.** Not a device that does something to you. A coach for four things
that are each real and each individually defensible:

| Mode | What it actually is | What backs it |
|---|---|---|
| **Breathe** | Watch taps an inhale/exhale rhythm (4 in, 6 out) so you can pace breathing with your eyes closed | RCTs of diaphragmatic and paced breathing on chemotherapy-induced and postoperative nausea |
| **Tone** | 1-minute 100 Hz pure tone, headphones, volume check | Nagoya 2025, cited in-app with the paper's own "may improve" hedge |
| **Press** | Locates P6, checks band or thumb position, times the pressure and reminds you (the trial protocol is 3x daily) | P6 *pressure* RCTs, including pregnancy and hyperemesis trials, with the Cochrane "evidence is limited" caveat stated |
| **Pulse** | The existing steady haptic pattern, described truthfully as a regular sensation to focus on while a wave passes | No mechanism claim attached. Framed like a breathing app's anchor |

The reframe on **Press** is the important one. Today the app implies the Watch
buzz *is* the acupressure, which is the false part. In the rebuild the Watch is
the coach and timer for pressure the user applies, with their thumb or with the
Sea-Band they already own. That is true, it matches the protocol the trials
actually ran, and it is more useful to a pregnant user than a buzz.

### The copy template: Dizzout, applied to a wrist band

Decided 2026-08-14. Dizzout is the model, because it is the freshest approval in
the niche (2026-08-07) and it makes a bolder surface claim than Queasy 1.0 ever
did while staying clean. Reverse-engineering how it does that:

1. **The outcome phrase lives in the app name, where it reads as a tagline.**
   "Dizzout - Stop Motion Sickness". Nobody treats a brand name as a mechanism
   claim.
2. **It never explains a mechanism.** No inner ear, no otoliths, no study, no
   acupressure. It says "put on your headphones and press play" and stops. Every
   1.1.6 finding lives in an unsupported mechanism sentence, so having none is
   the cheapest possible defence.
3. **It says "feelings of nausea", never "nausea".** "start the session ... to
   help reduce feelings of nausea and dizziness". Reducing a *feeling* is a
   comfort claim. Reducing nausea is a cleared-device claim.
4. **Its verbs are "support" and "designed to".** "Dizzout is designed to
   support you", "Non-drowsy support for motion sickness", "gives you a simple
   way to feel more prepared".
5. **It sits in Travel, not Health or Medical.**

Queasy takes 1 through 4 verbatim as a house style. It does not take 5: a nausea
app that covers hangover, vertigo and morning sickness does not belong in
Travel, and mis-categorising is its own 2.3.7 problem. Instead: keep
**Health & Fitness primary, add Travel as secondary, drop Medical**.

Queasy also keeps two things Dizzout omits, because Queasy sits in a health
category and carries two rejections on its record: the 100 Hz citation (with the
paper's own "may improve" hedge) and a short safety note.

House style, in one line: **the pulse is a sensation you feel on your wrist, not
something the watch does to your nervous system.**

### Pregnancy: where it goes

Decided 2026-08-14.

- **Not in the App Store name, subtitle, keywords, or screenshots.** Payoff is
  popularity 5; cost is re-opening a twice-rejected claim on an app record that
  already carries that history.
- **Yes as one listed occasion in the long description**, in a plain list next
  to motion, hangover and vertigo, with no outcome verb attached. Naming when
  you might use something is not claiming what it does.
- **Yes as a selectable context in the check-in**, with its own tracking and its
  own safety copy. Blocking the words from the product entirely makes the app
  worse for the user who needs it most and buys nothing once the claim is gone.
- **Yes in the product.** Morning sickness is the highest-value audience in this
  category by a distance: it lasts weeks, it is miserable, and it drives *daily*
  use, where motion sickness is a twice-a-year event. Pregnant users are the
  retention story.
- **Yes on the website and in outside channels**, where the constraint is
  truthful advertising rather than ASO, and where the audience actually is
  (BabyCenter and What to Expect forums, r/BabyBumps, r/HyperemesisGravidarum,
  TikTok, SEO). Name the audience, make no outcome claim.
- **In-app pregnancy support should be tracking and safety, not a claim.** A
  symptom and hydration log she can show her OB, trigger patterns (worse on an
  empty stomach, specific smells, time of day), and an explicit red-flag prompt
  ("if you cannot keep fluids down for 24 hours, call your provider"). That is
  approvable, genuinely useful, and it is the thing that gets someone with
  hyperemesis into actual care.

### Recommended store metadata

- **Name (28):** `Queasy - Wrist Nausea Relief`
  Wins `nausea relief` outright (difficulty 5, currently ranked 69) and picks up
  `wrist` (20). "Nausea" and "relief" are category vocabulary, not the mechanism
  claim that got 1.0 rejected. **Deliberately not "Band"**: Reliefband® is a
  registered trademark and "Nausea Relief Band" sits right on top of it, which
  2.3.7 warns about, and `sea band` / `wristband` both measure popularity 5 so
  the word buys nothing in search. "Band" stays in the description and
  screenshots, where it does its real job of explaining the idea.
- **Subtitle (29):** `Watch Pulse, Breathing & Tone`
  Pure feature description, which is exactly what 2.3.7 asks a subtitle to be,
  and it carries the two highest-volume reachable terms: `watch` (apple watch
  73, watch app 45) and `breathing` (breathing exercises 30).
- **Keywords (97):**
  `motion,sickness,sick,car,sea,seasick,carsick,travel,dizzy,vertigo,wrist,band,acupressure,p6,100hz`
  `motion sickness` is difficulty 5, so the keyword field alone should rank it.
  Nausea, relief, queasy, watch, breathing, tone, pulse and kit all come free
  from the name and subtitle, so none of them are repeated here.
- **Categories:** keep Health & Fitness primary, **drop Medical as secondary**
  (Travel is the better second). Medical is a scrutiny signal for zero browse
  benefit.
- **Description:** lead with the four modes and their citations; every claim
  verb hedged to match its source; keep the safety block.
- **Review notes:** rewrite to answer 1.1.6 head on, before it is asked. State
  that the app makes no treatment claim, name each mode's source, and state
  plainly that the haptic pattern is a sensation to focus on and is not
  presented as stimulation of anything.

---

## 6. Freemium redesign

Remove the hard paywall. In a niche with no search traffic, the binding
constraint is **ratings and word of mouth**, not conversion rate. Queasy has
zero ratings. A paywall between a nauseated person and a two-minute buzz is both
hostile and pointless: nobody enters card details while they are about to throw
up.

**Free, forever, no trial, no limit:**

- Quick Relief: a **2-minute** session on Watch or iPhone, at a sensible fixed
  intensity, unlimited uses. Two minutes rather than thirty seconds, because
  thirty seconds is a tease and reads as one. It sits between the Nagoya
  protocol (1 min) and Sense Relief's free session (3 min).
- The full Learn library, the P6 position guide, and the safety content.
- Basic logging: the last 7 days.

**Pro:**

- The 3-question check-in and the tailored plan it produces.
- Long sessions (10 to 45 min) with background running and live intensity.
- The 100 Hz tone mode.
- Full history, trends, "what actually helps you", export.

**Flow:** onboarding ends *in the app*, not on a paywall. The paywall appears
after the first completed session's "did that help?" moment, which is the
playbook's "trigger after demonstrated value". Settings and feature gates use
the full plan picker.

**Pricing: decided 2026-08-14, cut to $2.99 monthly / $14.99 yearly / $29.99
lifetime.** Down from $8.99 / $34.99 / $79.99, which was inherited from the
fleet raise and is far too high for a zero-rating utility in a dead niche that
now has a real free tier. This is a deliberate exception to the fleet
no-blanket-cut rule, which was written about apps that have install volume.
Both subscriptions keep their 1-week free trial.

---

## 7. Build order

1. **Claims pass.** Rewrite onboarding, recommendation, session, paywall, Learn,
   Settings, metadata (all locales), review notes, privacy page, and the site so
   nothing implies the device acts on the body.
2. **Freemium.** Remove the `RootView` paywall gate (`Queasy/App.swift:93`), add
   the free Quick Relief session and its ceiling, move the paywall to the
   post-session moment, add the feature gates.
3. **Breathe mode.** Haptic breathing pacer on Watch and iPhone. This becomes
   the flagship free session. Nobody else in the niche has it on the wrist.
4. **Press mode.** P6 locate, position check, timed pressure, 3x-daily reminder.
5. **Tone mode** promoted from a phone-session add-on to a first-class mode with
   its citation and headphone check.
6. **Log.** Extend the existing `ReliefEpisode` history into a symptom and
   trigger log with the red-flag prompt.
7. **Store.** New screenshots for the four modes, metadata in all locales,
   category change, resubmit.
8. **Site and channels.** Rebuild `docs/index.html` around the four modes, add a
   morning-sickness page that names the audience without claiming an outcome,
   then work the forums and social channels where that audience actually is.

---

## 8. Status, 2026-08-16: submitted

1.1.0 (build 20) is **WAITING_FOR_REVIEW**, set to release automatically on
approval. Everything in the old "still to do" list is done except the channel
work, which the App Store cannot do for us.

- **Listing.** `Queasy - Wrist Nausea Relief` / `Watch Pulse, Breathing & Tone`,
  categories Health & Fitness + **Travel** (Medical dropped), new description,
  keywords, screenshots and review notes, all 50 locales.
- **Prices.** Lifetime $29.99 took effect immediately; monthly $2.99 and yearly
  $14.99 are scheduled for 2026-08-17, which is the rolling minimum the API
  would accept. Existing subscribers move down with them (`preserveCurrentPrice`
  off, which is only ever safe on a cut). PPP ladder rebuilt at the new base:
  350 territory rows and one IAP schedule, no increases anywhere.
- **Localization.** 46 languages written against the new English source, one
  file per locale in `scripts/locale-copy/`. The hedges are the point and they
  are checked: every locale carries the paper's own "may improve", the Cochrane
  "limited and inconsistent", the not-acupressure-not-nerve-stimulation
  sentence, and the cleared-device disclaimer. Pregnancy stays out of every
  name, subtitle and keyword field in every locale.
- **Watch screenshots.** Recaptured on the rebuilt app (Quick start, Breathe,
  Press) via a DEBUG `-QueasyWatchScreen` launch argument, because a headless
  watch simulator can be launched but not tapped.

Two things worth knowing for next time: the review notes have a hard 4000-char
limit that deliver enforces by refusing the whole App Review Information step,
and `deliver --overwrite_screenshots` left duplicates behind (10 iPhone, 5
watch) that had to be deleted over the API before submitting.

Still open: **channels**, item 4 below. Nothing else is blocked.

## 8a. Status, 2026-08-14 (superseded)

Shipped in 1.1.0 (18):

- All four modes, on phone and wrist, with the check-in choosing between them.
- Freemium: no gate, unlimited free sessions, the paywall moved to after a
  session that actually hit the ceiling.
- Every claim surface rewritten, including the Learn card that states outright
  that a watch buzz is not acupressure.
- Morning sickness back as an occasion, in the app and the description.
- New App Store listing, screenshots, and review notes.
- Site rebuilt, with the morning-sickness section that carries the audience.
- 46 unit tests.

Still to do, in order:

1. **App Store Connect, before submitting.** The listing name change, prices cut
   to 2.99 / 14.99 / 29.99 via the shared `asc-*` scripts, secondary category
   Medical to Travel, then upload metadata and screenshots and submit. None of
   these are done: they are outward-facing and Jack's call to trigger.
2. **Watch screenshots.** Dropped from the set because they need a paired watch
   simulator and the old ones show the pre-rebuild UI. Recipe is in the
   `ios-dev` skill and `reference_watch_sim_testing`.
3. **Localized metadata: mostly done.** 29 of 50 locales carry translations, via
   `scripts/locale-copy/<locale>.json` with English fallback per field. All 27
   translated files were audited for claim drift and the hedges survive (the
   Nagoya title is left in English on purpose, so "may improve" cannot be
   paraphrased into a result). Remaining on English: the four English locales,
   plus the Indic, SE Asian, Arabic and Hebrew stores.
4. **Channels.** The site is ready; the audience is on BabyCenter and What to
   Expect forums, r/BabyBumps, r/HyperemesisGravidarum and TikTok, none of which
   the App Store can reach for us. This is the part that decides whether the
   rebuild matters, because organic search in this niche is worth close to
   nothing (see section 2).

## 9. What would make this wrong

- If Apple would in fact approve a hedged morning-sickness claim today, this
  plan leaves a little discovery on the table. The measured cost of finding out
  is a rejection on an app that already has two, and the measured prize is
  popularity 5. The asymmetry is why the plan does not test it.
- If the freemium tier is too generous, conversion falls. In a niche with no
  traffic that is the correct trade for a while: ratings first, revenue second.
  Revisit once there are 50-plus ratings.
- The demand read is US iPhone only. Worth re-pulling for DE, GB, JP before the
  locale metadata pass, in case `Reisekrankheit` or the JP travel-sickness terms
  carry more volume than the US equivalents.
