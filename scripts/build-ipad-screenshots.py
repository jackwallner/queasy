#!/usr/bin/env python3
"""Compose 13-inch iPad App Store screenshots (2064x2752) from raw iPad captures.

Same house style as build-screenshots.py: near-white canvas, two-tone rounded
headline, gray subhead, device bezel cropped off the bottom. Pulse needs a haptic
engine, so the iPad set says "three things" and the breathe frame says "follow".

Usage: python3 scripts/build-ipad-screenshots.py <raw-root> [locale ...]
  <raw-root>/<locale>/{1-home,2-breathe,3-press,4-recommend,5-learn,6-history}.png
Output: fastlane/screenshots/<locale>/ipad_0N_*.png
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
W, H = 2064, 2752
BG, INK, AQUA, GRAY = (243, 248, 247), (30, 48, 52), (52, 148, 137), (110, 130, 133)

FONTS = {
    "latin": ("/System/Library/Fonts/SFNSRounded.ttf", "/System/Library/Fonts/SFNS.ttf"),
    "ja": ("/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc", "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"),
}

# locale -> six (line1, line2, subhead) in frame order.
COPY = {
    "en-US": [
        ("Three things to try", "when you feel sick.", "Breathe, Tone and Press. All drug-free,\nall free and unlimited, no account."),
        ("A paced breath", "you can follow.", "A circle grows and fades at a steady pace.\nBreathe out for longer than you breathe in."),
        ("The spot a band", "sits on. Timed.", "Most people wear an acupressure band in the\nwrong place. Press shows you where."),
        ("Say what set it off.", "Get a mode to match.", "Three questions pick the mode with the most\nrelevant published work behind it."),
        ("Sources attached,", "not implied.", "Every mode says what it leans on, in the\nsource's own words, with a link."),
        ("See what actually", "settles you.", "Rate each session. History shows the mode you\ntend to come out of feeling better."),
    ],
    "ja": [
        ("気持ち悪いときに試せる", "3つの方法", "Breathe、Tone、Press\n薬を使わず、すべて無料で無制限、登録不要"),
        ("目で追える", "ゆったりした呼吸", "円が一定のペースで広がり、薄れていきます\n吸う息より、吐く息を長く"),
        ("押す場所を案内", "タイマーで計る", "手首のどこを押すかをPressが案内\n3分間のタイマー付き"),
        ("きっかけを伝えて", "合うモードを選ぶ", "3つの質問で、関連する公開研究が\n最も多いモードを選びます"),
        ("どのモードにも", "出典リンク付き", "各モードの根拠を、出典自身の言葉と\nリンクで紹介します"),
        ("よく使うモードが", "履歴でわかる", "セッションごとに評価をつけて\n履歴で試したモードを振り返れます"),
    ],
    "id": [
        ("Tiga hal untuk dicoba", "saat perut terasa mual", "Breathe, Tone, dan Press, tanpa obat\ngratis tanpa batas, tanpa akun"),
        ("Napas berirama", "yang bisa kamu ikuti", "Lingkaran membesar dan memudar dengan irama tetap\nEmbuskan napas lebih lama daripada menarik napas"),
        ("Titik yang ditekan", "dengan waktu terukur", "Press menunjukkan titik di pergelangan\ntangan dan menghitung tiga menit"),
        ("Sebut pemicunya", "dapatkan mode yang cocok", "Tiga pertanyaan memilih mode dengan\npenelitian terbit paling relevan"),
        ("Setiap mode", "disertai sumber", "Tiap mode menyebut dasarnya, dengan kata-\nkata sumber sendiri, lengkap dengan tautan"),
        ("Lihat mode mana", "yang sering kamu pakai", "Beri nilai tiap sesi, lalu buka Riwayat\nuntuk melihat sesi dan nilaimu"),
    ],
    "nl-NL": [
        ("Drie dingen voor", "als je misselijk bent", "Breathe, Tone en Press\nzonder medicijnen, gratis, geen account"),
        ("Een ademhaling", "die je kunt volgen", "Een cirkel groeit en vervaagt in een vast tempo\nAdem langer uit dan in"),
        ("Waar je moet drukken", "en hoe lang", "Press wijst de plek op je pols aan\nen houdt drie minuten bij"),
        ("Wat zet het aan?", "Krijg een passende modus", "Drie vragen kiezen de modus met het meeste\nbeschikbare onderzoek erachter"),
        ("Bronnen bij elke modus", "met een link", "Elke modus toont de bron, in de eigen\nwoorden van de studie, met link"),
        ("Zie welke modus", "je vaak kiest", "Beoordeel elke sessie, in Geschiedenis zie je\nje sessies en hoe je ze beoordeelde"),
    ],
}
RAW = ["1-home", "2-breathe", "3-press", "4-recommend", "5-learn", "6-history"]
NAMES = ["01_three", "02_breathe", "03_press", "04_match", "05_sources", "06_history"]


def font(locale: str, size: int, heavy: bool) -> ImageFont.FreeTypeFont:
    family = "ja" if locale == "ja" else "latin"
    paths = FONTS[family]
    f = ImageFont.truetype(paths[0] if heavy else paths[-1], size)
    if family == "latin":
        try:
            f.set_variation_by_name("Heavy" if heavy else "Regular")
        except OSError:
            pass
    return f


def compose(raw: Path, locale: str, line1: str, line2: str, sub: str) -> Image.Image:
    canvas = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(canvas)
    margin, y = 130, 170
    for line, color in ((line1, INK), (line2, AQUA)):
        size = 230
        f = font(locale, size, True)
        while draw.textbbox((0, 0), line, font=f)[2] > W - 2 * margin and size > 120:
            size -= 6
            f = font(locale, size, True)
        draw.text((margin, y), line, font=f, fill=color)
        y += int(size * 1.22)
    y += 50
    sub_font = font(locale, 80, False)
    for line in sub.split("\n"):
        draw.text((margin, y), line, font=sub_font, fill=GRAY)
        y += 108

    shot = Image.open(raw).convert("RGB")
    tw = int(W * 0.80)
    th = int(shot.size[1] * tw / shot.size[0])
    shot = shot.resize((tw, th), Image.LANCZOS)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, *shot.size], radius=64, fill=255)
    pad = 30
    bw, bh = tw + 2 * pad, th + 2 * pad
    bezel = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    ImageDraw.Draw(bezel).rounded_rectangle([0, 0, bw, bh], radius=96, fill=(16, 20, 21, 255))
    bezel.paste(shot, (pad, pad), mask)
    canvas.paste(bezel, ((W - bw) // 2, y + 90), bezel)
    return canvas


def main() -> None:
    raw_root = Path(sys.argv[1])
    for locale in sys.argv[2:] or list(COPY):
        out = ROOT / "fastlane" / "screenshots" / locale
        out.mkdir(parents=True, exist_ok=True)
        for old in out.glob("ipad_*.png"):
            old.unlink()
        for raw_name, name, (l1, l2, sub) in zip(RAW, NAMES, COPY[locale]):
            raw = raw_root / locale / f"{raw_name}.png"
            if not raw.exists():
                print(f"skip missing {raw}")
                continue
            compose(raw, locale, l1, l2, sub).save(out / f"ipad_{name}.png")
            print(f"wrote {locale}/ipad_{name}.png")


if __name__ == "__main__":
    main()
