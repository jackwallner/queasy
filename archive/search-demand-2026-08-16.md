# What people actually search, measured 2026-08-16

The question behind this: is the 1.1.0 reframe pointed at the right words, and
in particular is there a live query like "nausea relief band" or "nausea watch"
that Queasy should be capturing?

Short answer: no on the band and watch compounds, and the reframe is aimed one
notch off. The one term with demand in this space, in every storefront, is
**motion sickness** and its native-language equivalents. Queasy already owns
that in the keyword field of all 50 locales, and misses it entirely in the two
fields that weigh most, the name and the subtitle.

## Method, and why not just Astro

Astro popularity is a downstream copy of the Apple Ads keyword-popularity feed,
which collapsed thousands of mid-volume terms to the floor from ~2025-09-29. So
"popularity 5" no longer distinguishes a dead term from a term Apple stopped
reporting. That break is what makes the earlier "the whole symptom vocabulary is
dead" finding un-actionable on its own.

Two independent checks were run instead.

1. **Apple Ads search-term-popularity** (`POST v1/insights/apps/search-term-popularity/query`),
   the first-party numbers. Tooling is built and waiting at
   `~/ios/aso/tools/search-term-popularity/`, but `asc ads auth status` reports
   no stored credentials, so it did not run. Still blocked on the browser step
   in that README: create the free Apple Ads account, upload the existing public
   key, `asc ads auth login`.
2. **App Store search autocomplete** (`MZSearchHints`), a separate first-party
   surface that did not inherit the feed break, and which needs no account. New
   fleet tool at `~/ios/aso/tools/search-hints/`. This is what produced
   everything below.

Autocomplete answers presence, not volume. A bare term with no app name attached
is Apple surfacing a query; a list of app names is app-seeded and proves the
prefix is typed but not how often; an empty list across many storefronts is a
direct statement that nobody types it.

## The band and watch hypothesis is empty

Every one of these returns zero suggestions, US storefront:

`nausea relief` · `nausea b…` · `nausea w…` · `nausea watch` ·
`apple watch nausea` · `nausea wristband` · `acupressure band` ·
`acupressure wristband` · `relief band` · `reliefband` · `sea-band` · `psi band`
· `motion sickness watch` · `motion sickness apple watch` · `wrist band nausea`
· `dramamine` · `bonine` · `zofran`

An a-z sweep of `nausea ` returns exactly two suggestions in the entire query
space: **nausea tracker** and **nausea & vomiting tracker**. `sea band` returns
one thing, a game called Sea Bandit Blitz.

So the physical-product vocabulary does not exist on the App Store. People buy
Sea-Bands on Amazon; they do not go looking for one in the App Store. The brand
names return nothing at all, which is the cleanest form of the finding.

## `nausea` itself is barely a query, and only as a tracker

- US `nausea` -> `nausea tracker`, `nausea & vomiting tracker`. Nothing else.
- GB `nausea` -> nothing at all.
- FR `nausée`, ES `nauseas`, IT `nausea`, BR `nausea`, JP `吐き気`,
  NL `misselijk` -> all nothing.

Where the symptom word does surface, the noun attached to it is **tracker**,
which matches the shape everywhere else in the symptom space: `sickness tracker`,
`vertigo tracker`, `stomach ache tracker`, `chemo symptom tracker`,
`my sick family illness tracker`. Nobody searches a symptom hoping for relief.
They search it hoping to log it.

That is a real problem for a name whose second half is "Wrist Nausea Relief":
both nouns in it are words nobody types.

## `motion sickness` is live, everywhere, and is the whole opportunity

| storefront | term | what Apple suggests |
|---|---|---|
| US | motion sickness | bare term + 9 apps, incl. an editorial `recommended motion sickness relief apps` |
| GB / AU / CA | motion sickness | bare term + 6-8 apps |
| DE | reisekrankheit | bare term + 4 apps |
| FR | mal des transports | bare term + 4 apps |
| ES / MX | mareo | bare term + 4 apps |
| JP | 乗り物酔い | bare term + 2 apps |
| KR | 멀미 | bare term + 5 apps |
| CN | 晕车 | bare term |
| SE | åksjuka | 2 apps |
| IT | cinetosi | 1 app |
| BR | enjoo | 3 apps (buried under the Enjoei marketplace) |

The bare term appearing without an app name is the signal that matters: Apple is
completing a query, not advertising a competitor. It does that for the motion
sickness word in eight storefronts and for the nausea word in none.

US `car sickness` is also live (`ridecalm: car sickness control`), and GB
`travel sickness` returns the bare term.

Astro agrees where it can: `motion sickness` popularity 14, difficulty 5. That
is the only term in the entire earlier pull that is both non-floor and cheap.

## The SERP says winnable and small

Top of US `motion sickness`, with rating counts:

RideCalm 19 · Carsick.App 14 · AntiSick 0 · Hearapy 1 · Stellar 0 · NoMo 3 ·
Dizzout 3 · MoCue 0 · Sense Relief 38 · Motion Ease 0 · Not Dizzy 1 ·
MotionSicknessTone 14 · Ease Motion Sickness 0 · HearEase 0

Thirteen of the top fifteen have fewer than 20 ratings and six have zero. Four
of them are selling the same 100 Hz minute Queasy ships as Tone, and one
(Motion Ease) puts "100Hz" in its subtitle. Nothing here is defended. It also
confirms the ceiling: winning this SERP outright is worth a few dozen ratings a
year, which is the same conclusion as before. Search is not the growth channel.
It is the free floor, and right now Queasy is not standing on it.

## What to change

Everything below is a metadata edit. None of it needs a build, and none of it
touches the 1.1.6 guardrail, since naming an occasion is not claiming an outcome.

1. **Subtitle.** `Watch Pulse, Breathing & Tone` spends all 30 characters on
   mechanism, and mechanism is not searched. Replace with the live term, e.g.
   `Motion Sickness & Travel Aid` (28). Keep the app as the instrument.
2. **Name.** `Queasy - Wrist Nausea Relief` puts two unsearched words in the
   highest-weighted field. `Queasy - Motion Sickness Aid` is the same shape as
   Dizzout, the freshest approval in the niche, and swaps dead words for live
   ones. `Wrist` earns its place only if the subtitle drops it.
3. **Localized names and subtitles** should carry the native term from the table
   above, not a translation of "nausea". The keyword fields already do this
   correctly in all 50 locales, so only name and subtitle need the pass.
4. **Leave the keyword fields alone.** They are already right.

Caveat on ordering: 1.1.0 is in review with the current name. Editing name or
subtitle now means a metadata rejection risk and a resubmit, so this should land
as the first change after 1.1.0 is approved, not during.

## Addendum, same day: the Apple Ads numbers, now that the account exists

Credentials are registered and stored. Ad account `21296540`. The endpoint runs.
It does not overturn anything above, and it adds a hard ceiling.

**Apple publishes the top 500 search terms per genre, per country, per week, and
nothing else.** Fifteen genres, 7500 rows a week per storefront. Publication
lags about two weeks: on 2026-08-16 the week of 08-09 returned zero rows while
08-02 was fully populated.

Where the cutoff sits in the week of 2026-08-02:

| storefront | genre | terms published | popularity at the floor |
|---|---|---|---|
| US | Health & Fitness | 500 | 48 |
| US | Travel | 500 | 48 |
| GB | Health & Fitness | 457 | 44 |
| DE | Health & Fitness | 382 | 45 |

**Not one nausea, sickness, vertigo, dizziness, acupressure or band term appears
anywhere in the US, GB or DE census.** Not `motion sickness`, not `nausea`, not
`car sickness`, not `sea band`, not `breathing exercises`. So the whole niche
sits below Apple's publication floor.

Read this carefully, because it is a ceiling and not a floor. Absence means
"smaller than the 500th Health & Fitness term", which in the US is `rx local` at
popularity 48. It does not mean zero, and the autocomplete evidence above says
it is plainly not zero. What it does mean is that no naming decision in this
niche is worth agonising over: the entire addressable search volume is below the
threshold Apple bothers to report.

### The genre column settles the name question independently

Only four Queasy terms appear in the census at all, and Apple's own category
assignment for three of them is somewhere else entirely:

| term | Apple's genre | rank | pop |
|---|---|---|---|
| `band` | **Productivity & Utilities** | 63 | 69 |
| `car` | **Games** | 51 | 68 |
| `motion` | **Photo & Video** | 437 | 47 |
| `travel` | Travel | 188 | 55 |

`band` at popularity 69 is real volume, and it is Samsung Galaxy bands and music
apps, not sickness. `motion` is Alight Motion. `car` is racing games. Those are
exactly the three words in "Motion Sickness Vibration Band", and Apple's own
classifier says all three point away from this app. That is the SERP-intent
guardrail, mechanised, and it agrees with the autocomplete read.

`travel` is the one term Queasy holds that is both published and correctly
genred, which retroactively justifies the Travel category on 1.1.0 and supports
putting travel occasions in the subtitle.

### One locale-specific find worth keeping

`apple watch` is genred differently per storefront: Productivity & Utilities in
the US (rank 75, pop 67), Lifestyle in GB (rank 41, pop 55), and **Health &
Fitness in DE (rank 15, pop 65)**. So in Germany, and only in Germany so far,
"apple watch" is a health query near the top of the genre. That is a real,
measured opening for the German listing that no other locale offers.

## Applied, 2026-08-17

Not held back after all. 1.1.0 was pulled from review (the submission cancelled,
which drops the version to DEVELOPER_REJECTED and makes both the appInfo and the
version editable again), the three indexed fields were rewritten in all 50
locales, and it was resubmitted with build 20 still attached and release still
automatic on approval.

| field | before | after |
|---|---|---|
| name | Queasy - Wrist Nausea Relief | Queasy - Motion Sickness Aid |
| subtitle | Watch Pulse, Breathing & Tone | Wrist Vibration on Your Watch |
| keywords | motion,sickness,sick,car,sea,seasick,carsick,travel,dizzy,vertigo,band,acupressure,p6,100hz,breathe | sick,carsick,seasick,car,sea,boat,plane,cruise,train,travel,dizzy,vertigo,nausea,100hz,breathe,tone |

The subtitle is the part that changed in kind rather than in wording. The old
one listed mechanism, the new one explains the product: something vibrates, on
your wrist, and your watch is what does it. "Vibration" carries that with no
claim attached. "Band" would have carried it too and is the one word that cannot
be used, because it names the cleared-device class.

Localized names take the native head term Apple's autocomplete actually
completes: `Reisekrankheit`, `Mal des transports`, `Mareo por movimiento`,
`Cinetosi e mal d'auto`, `Enjoo de movimento`, `乗り物酔い`, `멀미`, `晕车晕船晕机`,
`Åksjuka och sjösjuka`. Every locale was checked for length and for a token
appearing in more than one of the three fields, which caught one collision in
Hebrew.

Pushed with the new `scripts/asc-push-listing-fields.py` rather than
`fastlane deliver`, so screenshots were left alone and the 4000-char review
notes trap was never touched.

## Still open

- Run the census across the remaining fleet storefronts, and the same read for
  the other apps. Tooling now supports it: `build_query.py --census`.
- Localized promotional text still carries the old English framing in the 46
  translated locales. Promotional text is editable without a review cycle, so it
  can be redone any time.
