---
paths:
  - "Queasy/**"
  - "Shared/**"
  - "QueasyWatch/**"
  - "Tools/Localization/**"
---

# Queasy: localization (added 2026-11-04)

Every user-facing string in the iPhone and Watch apps routes through the catalog,
which holds `en` only for now. Separate runs add the other languages, then list
them in `CFBundleLocalizations` in each Info.plist and in `LANGS` in `check.py`.
`android/` has its own strings and is out of this.

## Setup
- One catalog, `Shared/Localizable.xcstrings` (source `en`, every key
  `extractionState: manual`, every key with an `en` value). `Shared/` is a source
  of every target, so app, Watch and tests all compile it. XcodeGen 2.39+ reads
  its languages into `knownRegions`.
- Neither Info.plist holds a purpose string and the app has no App Shortcuts, so
  there is no `InfoPlist.xcstrings` or `AppShortcuts.xcstrings`. Add one if that
  changes. Display names are the brand and stay out.
- `python3 Tools/Localization/check.py` (repo root, no Xcode needed) fails on a
  source literal with no key, a key with no source, a missing `en` value,
  mismatched format specifiers, and plain copy that can reach the screen: a
  `return "..."`, a ternary or `??` of literals, a `case .x: "..."`, an
  assignment, a copy-named argument, a copy helper's first argument, a
  sentence-shaped literal, or a literal beside a String expression inside
  `Text(...)`. Run it before every build that touches copy. Identifiers it
  mistakes for copy go in its `ALLOWED` set, and new copy helpers in `COPY_FUNCS`.
- `check.py` compares `%@` and `%lld` loosely, since it has no compiler. The
  catalog key must match what Swift generates exactly (`Int` is `%lld`, `String`
  is `%@`), or the lookup silently falls back to the English in the source.
- `LocalizationTests` proves the catalog compiles to `en.lproj` and that plural,
  substitution, percent and formatter output keep the English wording.
  `scripts/sync-android-parity.sh` compiles the models with no catalog, so a
  changed key's English shows up there as a fixture diff.

## Adding or changing copy
- `Text("literal")`, `Button`, `Label`, `Section`, `navigationTitle`, `alert` and
  friends localize themselves. Copy held in a `String` (view parameters, enums,
  notifications, error messages) must be `String(localized: "...")`. Logs,
  analytics, RevenueCat ids, stored keys and tags stay plain.
- `Text(flag ? "literal" : someString)` compiles to String and shows the literal
  verbatim. Wrap the literal in `String(localized:)`.
- Whole sentences only, never spliced fragments. Branch and give each variant its
  own key (see `quickCaption` in `RelieveHomeView`, `specDescription` in
  `CheckInView`, `suggestedHeading` on `NauseaCause` and `queasyTrialCopy` in
  `SubscriptionService`). No `.capitalized` or `.lowercased()` on copy, and no
  logic that reads translated text.
- Counts go in plural variations, or a `%#@n@` substitution when the sentence has
  other arguments. A count whose English never changes still carries a plural
  with `other` only, so a translator sees it is a count. English only has a `one`
  form where the source already had a singular wording.
- A count label drawn beside a separately rendered number cannot be a plural key:
  Xcode rejects plural variants that omit the number. `PluralLabel` asks the
  catalog's `"%lld plural category"` key for the CLDR category, then picks one
  whole key per category. The `(few)`, `(many)` and `(one)` keys carry an `en`
  value so English never shows the key.
- Clocks and decimals go through `DisplayFormat`; bare numbers through
  `Text(n, format: .number)`. Prices come only from StoreKit, apart from the
  screenshot mock in `PaywallView`, which is keyed as it stands.
- Never localize stored values: `causeRaw`, `modeRaw`, `sourceRaw`, sync payloads
  and the CSV columns stay as they are. `ReliefPlan.tips` is saved and sent to the
  Watch in English, wrapped in `storedCatalogKey(...)`; screens read
  `displayTips`. Analytics reads `queasyAnalyticsPlan`, not the display name.
- Brand stays untranslated in meaning: Queasy, Queasy Pro, Apple Watch, Sea-Band,
  Reliefband, and the mode names as the app defines them.
- Translations are claims too. The rules in `AGENTS.md` and `docs/positioning.md`
  (who the subject of the sentence is, the source's own hedges) apply in every
  language.

## Proving a change
`python3 Tools/Localization/check.py`, then `gh-sim test --scheme Queasy`.
