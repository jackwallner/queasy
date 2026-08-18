#!/usr/bin/env python3
"""Generate fastlane/metadata/<locale>/ files for Queasy.

Single source of truth for App Store listing copy. Validates ASC field limits
(name/subtitle 30, keywords 100, promotional 170) before writing. Rerun after
editing; then upload with scripts/upload-appstore-metadata.sh.

COPY RULES (see docs/positioning.md, which explains why):

  1. The outcome phrase lives in the app name, where it reads as a name. It
     does not appear as a verb anywhere else.
  2. No sentence asserts a mechanism. Every 1.1.6 finding lives in an
     unsupported mechanism sentence, so there are none.
  3. "Feelings of nausea", not "nausea". Reducing a feeling is a comfort claim;
     reducing nausea is a cleared-device claim, and Queasy holds no clearance.
  4. Verbs are "support", "designed to", "try". Where a claim is unavoidable it
     is quoted in the source's own hedge.
  5. No brand names of cleared devices, and no price figures (fleet rule).

LOCALIZATION. The English copy below is the source. Per-locale translations live
one file per locale in `scripts/locale-copy/<locale>.json`, and any field a
locale omits falls back to English. Before 2026-08 this file held 90 hand-written
localizations, all of which were written pre-rejection and all of which carried
the exact claims App Review threw out; they were deleted rather than updated, and
`locale-copy/` is their replacement, written against the copy rules above. The
rules bind the translations too: check the hedges survive ("feelings of nausea",
"may improve", "designed to"), because a hedge is the easiest thing in the world
to translate away.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "fastlane" / "metadata"

SUPPORT_URL = "https://jackwallner.github.io/queasy/"
PRIVACY_URL = "https://jackwallner.github.io/queasy/privacy-policy.html"
COPYRIGHT = "2026 Jack Wallner"

# Health & Fitness stays primary: it is where a nausea app belongs, and putting
# it somewhere softer to dodge reviewers would be its own 2.3.7 problem. Medical
# goes, though. It bought no browse traffic and signalled "scrutinise me".
PRIMARY_CATEGORY = "HEALTH_AND_FITNESS"
SECONDARY_CATEGORY = "TRAVEL"

# The three indexed fields are ONE pool: name, subtitle and keywords are
# concatenated before Apple tokenises them, so a word repeated across two fields
# is paid for twice and counted once. Nothing below appears in more than one.
# Measured 2026-08-16, see docs/search-demand-2026-08-16.md.

# 28 chars. "Motion sickness" is the only phrase in this niche that is a live
# query: App Store autocomplete completes the bare term in the US, GB, AU, CA
# and in the native word for it in DE, FR, ES, MX, JP, KR and CN. It completes
# nothing at all for "nausea relief", which is why that phrase left the name.
NAME = "Queasy - Motion Sickness Aid"

# 29 chars. The subtitle's job is comprehension, not occasion-listing: it has to
# tell someone reading the card that a watch buzzes on their wrist. Deliberately
# "vibration" and not "band". Vibration describes what the hardware does and
# claims nothing. "Band" names the product class that Sea-Band and Reliefband
# occupy, which are FDA-cleared Class II devices, and calling this app one of
# those is the 1.1.6 finding in its purest form (see docs/positioning.md).
# It also earns nothing: Apple genres "band" to Productivity & Utilities, where
# it means Samsung Galaxy bands and music apps.
# Not "Apple Watch" either, since Apple product names in name or subtitle draw
# trademark rejections.
SUBTITLE = "Wrist Vibration on Your Watch"

# 99 chars. Motion, sickness, queasy and aid come free from the name; wrist,
# vibration and watch come free from the subtitle. So none of those are here,
# and the freed characters went to the travel occasions the subtitle no longer
# carries. Dropped from the previous field: "band" (wrong genre at scale), and
# "acupressure" and "p6", which assert the mechanism the claims guardrail
# forbids while buying traffic in the wrong category.
KEYWORDS = (
    "sick,carsick,seasick,car,sea,boat,plane,cruise,train,"
    "travel,dizzy,vertigo,nausea,100hz,breathe,tone"
)

# 160 chars. Promotional text is not indexed, and it is the one field editable
# without a new build or a review cycle, so it carries the explanation the
# 30-char subtitle cannot. "Nothing to buy or pack" tells a Sea-Band-aware
# reader what this is without naming a cleared device or claiming its effect.
PROMOTIONAL_TEXT = (
    "Nothing to buy or pack. Your watch taps a rhythm you can feel, paces a "
    "breath, or plays the 100 Hz minute. Start one in a second, before the "
    "car, boat or plane."
)

DESCRIPTION = """Queasy is four drug-free things to try when you feel sick, on your Apple Watch or your iPhone. Start one in a tap, or answer three quick questions and let Queasy choose.

FOUR MODES
- Pulse: a steady, unhurried tap on the inside of your wrist. Something to rest your attention on while a wave passes. Ten levels, adjustable mid-session.
- Breathe: your watch taps a long swell in and a longer fade out, so you can pace your breathing with your eyes shut and your arm down.
- Tone: a pure 100 Hz tone for one minute, through headphones, at everyday volume.
- Press: shows you the spot on the inside of your wrist that an acupressure band sits on, then times a three-minute hold while you press with your thumb or line up a band you already own.

FOR WHATEVER SET IT OFF
Car, boat, plane and train. Morning sickness. Hangovers. Vertigo and dizzy spells. A nervous stomach. Pick the occasion and Queasy suggests the mode with the most relevant published work behind it, then gets out of the way.

FREE, UNLIMITED, NO ACCOUNT
Every mode works free, as often as you like. Free Pulse and Breathe sessions run two minutes; Tone and Press always run their full length. Queasy Pro adds sessions up to 45 minutes that keep going on your wrist with the screen off, your whole history and which mode tends to settle you, your own rhythm and level, and Press reminders through the day.

WITH THE SOURCES ATTACHED
Each mode says what it leans on, in the source's own words, and links to it. The tone comes from a 2025 Nagoya University paper titled "Just 1-min exposure to a pure tone at 100 Hz with daily exposable sound pressure levels may improve motion sickness". The wrist spot Press uses is the one studied in acupressure-band trials, where the Cochrane review of early-pregnancy trials calls the evidence limited and inconsistent. We would rather tell you that than not.

Pulse is the one mode with nothing to cite, and it says so. A watch tapping your wrist is not acupressure and not nerve stimulation. It is a regular sensation that is easy to focus on, which is the only thing Queasy claims for it.

PRIVATE BY DESIGN
Your check-ins, sessions and settings stay on your devices. No account, no ads, no tracking, and you can export the log for a doctor at any time.

IMPORTANT
Queasy is a set of comfort techniques you run yourself. It is not a medical device, it holds no clearance, and it does not diagnose, treat, cure or prevent anything. It may not change how you feel. Acupressure bands and wrist stimulation devices sold for nausea are cleared medical devices; Queasy is neither, and is not a substitute for one. If nausea is severe or persistent, comes with other symptoms, or you cannot keep fluids down, talk to a doctor. In pregnancy, sickness that stops you keeping fluids down needs your midwife or doctor, not an app.

Queasy Pro is a monthly or yearly auto-renewing subscription, each with a 1-week free trial, or a separate one-time lifetime purchase. Payment is charged to your Apple Account. Subscriptions auto-renew unless cancelled at least 24 hours before the current period ends. Manage or cancel in App Store settings."""

RELEASE_NOTES = """Queasy is rebuilt around four things instead of one.

- Pulse is still here: a steady tap on the inside of your wrist.
- Breathe paces a slow breath on your wrist, long in and longer out, so you can follow it with your eyes shut.
- Tone plays the 100 Hz minute from the 2025 Nagoya University study.
- Press shows you the spot an acupressure band sits on and times a three-minute hold.

Every mode is now free and unlimited, with no account and no gate on the way in. Free Pulse and Breathe sessions run two minutes; Tone and Press run their full length. Each mode shows what it leans on, in the source's own words, with a link.

Morning sickness is back as an occasion, with its own gentler settings, its own guidance, and a plain note about when to call your midwife or doctor instead."""

LEGAL_LINKS = f"""

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: {PRIVACY_URL}"""

# Every App Store locale the app is available in. Each one takes the English copy
# unless scripts/locale-copy/<locale>.json overrides a field; see the docstring.
LOCALES = [
    "ar-SA", "bn-BD", "ca", "cs", "da", "de-DE", "el", "en-AU", "en-CA",
    "en-GB", "en-US", "es-ES", "es-MX", "fi", "fr-CA", "fr-FR", "gu-IN", "he",
    "hi", "hr", "hu", "id", "it", "ja", "kn-IN", "ko", "ml-IN", "mr-IN", "ms",
    "nl-NL", "no", "or-IN", "pa-IN", "pl", "pt-BR", "pt-PT", "ro", "ru", "sk",
    "sl-SI", "sv", "ta-IN", "te-IN", "th", "tr", "uk", "ur-PK", "vi",
    "zh-Hans", "zh-Hant",
]

LIMITS = {"name": 30, "subtitle": 30, "keywords": 100, "promotional_text": 170}

ENGLISH = {
    "name": NAME,
    "subtitle": SUBTITLE,
    "keywords": KEYWORDS,
    "promotional_text": PROMOTIONAL_TEXT,
    "description": DESCRIPTION,
    "release_notes": RELEASE_NOTES,
}

LOCALE_COPY = Path(__file__).resolve().parent / "locale-copy"

# Regional variants borrow their parent's copy rather than falling all the way
# back to English, which is strictly worse in those stores. The shared text is
# written in forms that work on both sides of the Atlantic (usted/tú rather than
# vosotros); if that ever stops being true, give the variant its own file and it
# wins outright.
FALLBACK = {"es-MX": "es-ES", "fr-CA": "fr-FR", "pt-PT": "pt-BR"}


def _read(locale: str) -> dict:
    path = LOCALE_COPY / f"{locale}.json"
    if not path.exists():
        return {}
    override = json.loads(path.read_text())
    unknown = set(override) - set(ENGLISH) - {"_note"}
    if unknown:
        raise SystemExit(f"{locale}: unknown field(s) {sorted(unknown)}")
    return {k: v for k, v in override.items() if k in ENGLISH}


def load_locale(locale: str) -> dict:
    """English, overridden by the locale's own file, or its parent's."""
    fields = dict(ENGLISH)
    if parent := FALLBACK.get(locale):
        fields.update(_read(parent))
    fields.update(_read(locale))
    return fields


def validate(locale: str, fields: dict) -> None:
    for field, limit in LIMITS.items():
        value = fields[field]
        if len(value) > limit:
            raise SystemExit(
                f"{locale}: {field} is {len(value)} chars (limit {limit}): {value!r}"
            )
    body = fields["description"] + LEGAL_LINKS
    if len(body) > 4000:
        raise SystemExit(
            f"{locale}: description is {len(body)} chars with legal links (limit 4000)"
        )
    if len(fields["release_notes"]) > 4000:
        raise SystemExit(f"{locale}: release notes are {len(fields['release_notes'])} chars (limit 4000)")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "copyright.txt").write_text(COPYRIGHT + "\n")
    (OUT / "primary_category.txt").write_text(PRIMARY_CATEGORY + "\n")
    (OUT / "secondary_category.txt").write_text(SECONDARY_CATEGORY + "\n")

    translated = 0
    for locale in LOCALES:
        fields = load_locale(locale)
        validate(locale, fields)
        if (LOCALE_COPY / f"{locale}.json").exists() or locale in FALLBACK:
            translated += 1

        d = OUT / locale
        d.mkdir(parents=True, exist_ok=True)
        (d / "name.txt").write_text(fields["name"] + "\n")
        (d / "subtitle.txt").write_text(fields["subtitle"] + "\n")
        (d / "keywords.txt").write_text(fields["keywords"] + "\n")
        (d / "promotional_text.txt").write_text(fields["promotional_text"] + "\n")
        (d / "description.txt").write_text(fields["description"] + LEGAL_LINKS + "\n")
        (d / "release_notes.txt").write_text(fields["release_notes"] + "\n")
        (d / "support_url.txt").write_text(SUPPORT_URL + "\n")
        (d / "marketing_url.txt").write_text(SUPPORT_URL + "\n")
        (d / "privacy_url.txt").write_text(PRIVACY_URL + "\n")

    print(f"name        {len(NAME):>3}/30   {NAME}")
    print(f"subtitle    {len(SUBTITLE):>3}/30   {SUBTITLE}")
    print(f"keywords    {len(KEYWORDS):>3}/100")
    print(f"promotional {len(PROMOTIONAL_TEXT):>3}/170")
    print(f"description {len(DESCRIPTION + LEGAL_LINKS):>4}/4000")
    print(f"wrote metadata for {len(LOCALES)} locales to {OUT}")
    print(f"  translated: {translated}   English fallback: {len(LOCALES) - translated}")


if __name__ == "__main__":
    main()
