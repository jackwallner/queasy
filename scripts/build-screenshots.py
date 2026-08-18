#!/usr/bin/env python3
"""Compose App Store marketing screenshots from raw simulator captures.

House style (matches the rest of the portfolio): near-white canvas, huge
two-tone rounded-bold headline (ink first line, aqua second), gray subhead,
then the app in a black device bezel that crops off the bottom of the canvas.

Usage: python3 scripts/build-screenshots.py <raw-shots-dir>
Output: fastlane/screenshots/en-US/ at 1284x2778 + raw watch shots copied.
"""

import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "fastlane" / "screenshots" / "en-US"
W, H = 1284, 2778

BG = (243, 248, 247)      # near-white seafoam
INK = (30, 48, 52)         # deep petrol
AQUA = (52, 148, 137)      # brand accent, darkened for text contrast
GRAY = (110, 130, 133)     # subhead

# (style, raw file, output name, line1(ink), line2(aqua), subhead)
# House copy rules apply here as hard as anywhere: see docs/positioning.md. No
# headline promises an outcome, none compares Queasy to a cleared device, and
# none implies the watch does something to you. Shot 1 carries the offer (four
# things, free), 2 and 3 carry the two modes nobody else in the niche has.
PLAN = [
    ("phone", "1-home.png", "appstore_01_four",
     "Four things to try", "when you feel sick.",
     "Pulse, Breathe, Tone and Press. All drug-free,\nall free and unlimited, no account."),
    ("phone", "2-breathe.png", "appstore_02_breathe",
     "A paced breath", "you can feel.",
     "Your watch taps a long swell in and a longer\nfade out. Follow it with your eyes shut."),
    ("phone", "3-press.png", "appstore_03_press",
     "The spot a band", "sits on. Timed.",
     "Most people wear an acupressure band in the\nwrong place. Press shows you where."),
    ("phone", "4-recommend.png", "appstore_04_match",
     "Say what set it off.", "Get a mode to match.",
     "Three questions pick the mode with the most\nrelevant published work behind it."),
    ("phone", "5-learn.png", "appstore_05_sources",
     "Sources attached,", "not implied.",
     "Every mode says what it leans on, in the\nsource's own words, with a link."),
    ("phone", "6-history.png", "appstore_06_history",
     "See what actually", "settles you.",
     "Rate each session. History shows the mode you\ntend to come out of feeling better."),
]

# Raw watch captures, copied through when present. Needs a paired watch
# simulator (see the ios-dev skill); the phone set above stands alone.
WATCH_SHOTS = ["w1-home.png", "w2-session.png", "w3-rating.png"]

FONT_PATHS = [
    "/System/Library/Fonts/SFNSRounded.ttf",
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/HelveticaNeue.ttc",
]


def font(size: int, weight: str = "Bold") -> ImageFont.FreeTypeFont:
    for path in FONT_PATHS:
        try:
            f = ImageFont.truetype(path, size)
        except OSError:
            continue
        try:
            f.set_variation_by_name(weight)
        except OSError:
            pass
        return f
    return ImageFont.load_default(size)


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, *img.size], radius=radius, fill=255)
    img = img.convert("RGBA")
    img.putalpha(mask)
    return img


def compose(raw: Path, line1: str, line2: str, subhead: str) -> Image.Image:
    canvas = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(canvas)

    margin = 84
    y = 150
    headline_font = font(148, "Heavy")
    for line, color in [(line1, INK), (line2, AQUA)]:
        # Shrink to fit width if needed.
        f = headline_font
        size = 148
        while draw.textbbox((0, 0), line, font=f)[2] > W - 2 * margin and size > 88:
            size -= 6
            f = font(size, "Heavy")
        draw.text((margin, y), line, font=f, fill=color)
        y += int(size * 1.22)

    y += 40
    sub_font = font(58, "Regular")
    for line in subhead.split("\n"):
        draw.text((margin, y), line, font=sub_font, fill=GRAY)
        y += 78

    # Device bezel, cropped off the bottom edge.
    shot = Image.open(raw)
    target_w = int(W * 0.70)
    target_h = int(shot.size[1] * target_w / shot.size[0])
    shot = rounded(shot.resize((target_w, target_h), Image.LANCZOS), radius=100)

    bezel_pad = 26
    bezel_w, bezel_h = target_w + 2 * bezel_pad, target_h + 2 * bezel_pad
    bezel = Image.new("RGBA", (bezel_w, bezel_h), (0, 0, 0, 0))
    ImageDraw.Draw(bezel).rounded_rectangle([0, 0, bezel_w, bezel_h], radius=126, fill=(16, 20, 21, 255))
    bezel.paste(shot, (bezel_pad, bezel_pad), shot)

    x = (W - bezel_w) // 2
    top = y + 90
    canvas.paste(bezel, (x, top), bezel)
    return canvas


BAND = (70, 165, 154)       # silicone aqua, brand-tinted
BAND_DEEP = (33, 104, 96)   # shaded edge


def _strap(width: int, height: int, holes: bool) -> Image.Image:
    """A silicone watch strap: vertical sheen gradient, rounded ends, optional
    adjustment holes toward the far end."""
    strap = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    px = strap.load()
    for x in range(width):
        # Center-bright cross-section so it reads as a rounded rubber strap.
        t = abs((x / (width - 1)) - 0.5) * 2  # 0 center -> 1 edge
        r = int(BAND[0] + (BAND_DEEP[0] - BAND[0]) * t)
        g = int(BAND[1] + (BAND_DEEP[1] - BAND[1]) * t)
        b = int(BAND[2] + (BAND_DEEP[2] - BAND[2]) * t)
        for y in range(height):
            px[x, y] = (r, g, b, 255)
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, width, height], radius=width // 3, fill=255)
    strap.putalpha(mask)
    if holes:
        d = ImageDraw.Draw(strap)
        hr = max(6, width // 22)
        for i in range(3):
            cy = int(height * (0.16 + i * 0.11))
            d.ellipse([width // 2 - hr, cy - hr, width // 2 + hr, cy + hr], fill=(20, 40, 42, 190))
    return strap


def draw_watch_band(canvas: Image.Image, case_left: int, case_top: int,
                    case_w: int, case_h: int, top_limit: int) -> None:
    """Silicone straps tucking under the watch case, top and bottom, so the hero
    reads as a wearable relief band, not just a screen. Straps stay below
    `top_limit` so they never cover the headline/subhead."""
    cx = case_left + case_w // 2
    strap_w = int(case_w * 0.56)
    overlap = int(case_h * 0.16)  # slip under the case corners

    top_start = max(top_limit, 0)
    top_h = case_top + overlap - top_start
    if top_h > 20:
        top_strap = _strap(strap_w, top_h, holes=False)
        canvas.paste(top_strap, (cx - strap_w // 2, top_start), top_strap)

    bot_top = case_top + case_h - overlap
    bot_h = canvas.size[1] - bot_top       # run off the bottom edge
    bot_strap = _strap(strap_w, bot_h, holes=True)
    canvas.paste(bot_strap, (cx - strap_w // 2, bot_top), bot_strap)


def compose_watch(raw: Path, line1: str, line2: str, subhead: str) -> Image.Image:
    """Hero variant: the Apple Watch, oversized, is the product shot."""
    canvas = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(canvas)

    margin = 84
    y = 150
    headline_font = font(148, "Heavy")
    for line, color in [(line1, INK), (line2, AQUA)]:
        f = headline_font
        size = 148
        while draw.textbbox((0, 0), line, font=f)[2] > W - 2 * margin and size > 88:
            size -= 6
            f = font(size, "Heavy")
        draw.text((margin, y), line, font=f, fill=color)
        y += int(size * 1.22)

    y += 40
    sub_font = font(58, "Regular")
    for line in subhead.split("\n"):
        draw.text((margin, y), line, font=sub_font, fill=GRAY)
        y += 78

    shot = Image.open(raw)
    # Drop the simulator status row (clock + red phone-disconnected icon).
    shot = shot.crop((0, 92, shot.size[0], shot.size[1]))
    target_w = int(W * 0.62)
    target_h = int(shot.size[1] * target_w / shot.size[0])
    shot = rounded(shot.resize((target_w, target_h), Image.LANCZOS), radius=180)

    bezel_pad = 40
    bezel_w, bezel_h = target_w + 2 * bezel_pad, target_h + 2 * bezel_pad
    crown_w, crown_h = 26, 150
    frame = Image.new("RGBA", (bezel_w + crown_w, bezel_h), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(frame)
    # Digital crown + side button behind the case
    fdraw.rounded_rectangle(
        [bezel_w - 8, int(bezel_h * 0.22), bezel_w + crown_w - 4, int(bezel_h * 0.22) + crown_h],
        radius=13, fill=(40, 46, 48, 255),
    )
    fdraw.rounded_rectangle(
        [bezel_w - 8, int(bezel_h * 0.52), bezel_w + crown_w - 10, int(bezel_h * 0.52) + int(crown_h * 0.8)],
        radius=11, fill=(40, 46, 48, 255),
    )
    fdraw.rounded_rectangle([0, 0, bezel_w, bezel_h], radius=220, fill=(16, 20, 21, 255))
    frame.paste(shot, (bezel_pad, bezel_pad), shot)

    x = (W - bezel_w - crown_w) // 2
    top = y + 130
    # Straps behind the case: emerge below the subhead, tuck under, run off-frame.
    draw_watch_band(canvas, x, top, bezel_w, bezel_h, top_limit=y + 30)
    canvas.paste(frame, (x, top), frame)
    return canvas


def main() -> None:
    raw_dir = Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.png"):
        old.unlink()
    for style, raw_name, out_name, l1, l2, sub in PLAN:
        raw = raw_dir / raw_name
        if not raw.exists():
            print(f"skip missing {raw}")
            continue
        composer = compose_watch if style == "watch" else compose
        composer(raw, l1, l2, sub).save(OUT / f"{out_name}.png")
        print(f"wrote {out_name}.png")
    for w in WATCH_SHOTS:
        src = raw_dir / w
        if src.exists():
            shutil.copy(src, OUT / f"watch_{w}")
            print(f"copied watch_{w}")


if __name__ == "__main__":
    main()
