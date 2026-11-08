#!/usr/bin/env python3
"""bands.py FRAME Ytop Ybottom : print ink bands (rows, x range, darkest color) above the phone."""
import sys
import numpy as np
from PIL import Image
a = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(int)
y0, y1 = int(sys.argv[2]), int(sys.argv[3])
bg = a[5, 5]
d = np.abs(a[y0:y1] - bg).sum(axis=2) > 40
rows = d.any(axis=1)
y = 0
while y < len(rows):
    if rows[y]:
        s = y
        while y < len(rows) and rows[y]: y += 1
        cols = np.flatnonzero(d[s:y].any(axis=0))
        blk = a[y0 + s:y0 + y]
        mask = d[s:y]
        px = blk[mask]
        c = px[px.sum(axis=1).argmin()]
        print(f"rows {y0+s}-{y0+y} h={y-s} x {cols.min()}-{cols.max()} dark={c.tolist()}")
    y += 1
