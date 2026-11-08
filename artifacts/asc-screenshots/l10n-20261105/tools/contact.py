#!/usr/bin/env python3
"""contact.py OUT.jpg IMG... : tile images side by side at small size."""
import sys
from PIL import Image
out, files = sys.argv[1], sys.argv[2:]
ims = [Image.open(f).convert("RGB") for f in files]
h = 900
ims = [i.resize((int(i.width * h / i.height), h)) for i in ims]
sheet = Image.new("RGB", (sum(i.width for i in ims) + 8 * len(ims), h), "white")
x = 0
for i in ims:
    sheet.paste(i, (x, 0)); x += i.width + 8
sheet.save(out, quality=80)
