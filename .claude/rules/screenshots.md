---
paths:
  - "artifacts/asc-screenshots/**"
  - "fastlane/screenshots/**"
  - "Queasy/**/Screenshot*"
---

# Queasy: localized store screenshots

## Localized store sets
Phone frames (iPhone 6.5, 1284x2778) for the eight target locales live in
`fastlane/screenshots/<store_locale>/` with the English filenames. Watch and Duo
sets stay English. Raws stay out of git.

Recapture and rebuild from `artifacts/asc-screenshots/l10n-20261105/` (the kit):
- `tools/capture.sh [store_locale ...]` runs one `gh-sim launch` job (iPhone 17
  Pro Max) with one `--screen` per scene and locale, en-US included as baseline,
  and sorts shots into `raw/<locale>/phone/`. Scenes are in `tools/scenes.json`
  and use the DEBUG `-QueasyStoreFrames` hook. `capture.py --from <run id>`
  sorts an existing run (shot order must equal app.json target order).
- `tools/compose.py [store_locale ...]` runs reskin, sheet and gate for each
  locale and copies PASSing sets into fastlane. Slow (about a minute a locale).
- Copy is `copy/headers.json`: `<file>` is the two-line headline (line 1 dark,
  line 2 aqua), `<file>#sub` the one or two line subhead. Geometry is
  `frames.json` (screen rects from `locate.py --bezel`, text boxes measured with
  `tools/bands.py`); the English live frames in `en-live/` are the base.

Quirks:
- `reskin.py` renders each text line as its own job, so line spacing matches the
  English frames; headline and subhead sizes are uniform per locale.
- `headline.swift` uses `system-regular` for the subhead and per-locale CJK and
  Thai fallbacks; Cyrillic uses the system bold.
- Current home screen differs from the live frame 1 (new "Feeling queasy?"
  layout); the header is unchanged.
- Mode names (Pulse, Breathe, Tone, Press) stay English in copy as in the app.
- GitHub's Macs queue for hours at night; submit one job and wait.
