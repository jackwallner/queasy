#!/usr/bin/env python3
"""Generate the Queasy app icon (1024x1024) for iOS and watchOS asset catalogs.

Design: deep-petrol -> aqua vertical gradient, a glowing pulse dot near the
bottom (the wrist point) with three ripple arcs expanding upward (the
vibration). Reads at 29pt and inside the circular watch mask.
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
S = 2048  # supersample, downscaled to 1024


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(top, bottom):
    img = Image.new("RGB", (S, S))
    px = img.load()
    for y in range(S):
        row = lerp(top, bottom, y / (S - 1))
        for x in range(S):
            px[x, y] = row
    return img


def main():
    top = (24, 60, 66)      # deep petrol
    bottom = (85, 181, 169)  # aqua
    img = gradient(top, bottom)

    # Radial glow behind the glyph so it pops on both gradient ends.
    glow = Image.new("L", (S, S), 0)
    gd = ImageDraw.Draw(glow)
    cx, cy = S // 2, S // 2
    gd.ellipse([cx - 620, cy - 620, cx + 620, cy + 620], fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    img.paste(Image.new("RGB", (S, S), (200, 245, 238)), (0, 0), glow)

    draw = ImageDraw.Draw(img, "RGBA")
    white = (255, 255, 255)

    # Center pulse dot with full concentric ripple rings — water-calm, not WiFi.
    cx, cy = S // 2, S // 2
    r = 96
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=white + (255,))
    rings = [(300, 92, 235), (540, 76, 165), (780, 62, 95)]
    for radius, width, alpha in rings:
        bbox = [cx - radius, cy - radius, cx + radius, cy + radius]
        draw.ellipse(bbox, outline=white + (alpha,), width=width)

    out = img.resize((1024, 1024), Image.LANCZOS)
    for rel in [
        "Queasy/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
        "QueasyWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
    ]:
        path = ROOT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        out.save(path)
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
