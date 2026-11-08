#!/usr/bin/env python3
"""Replace captures and CoreText headers in finished screenshot frames."""
from __future__ import annotations

import argparse
import sys
import tempfile
from pathlib import Path

from PIL import Image

from common import config, destinations, erase_header, headline, paste_screen, raw_path, read_json, source


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--config', type=Path, required=True)
    p.add_argument('--raw-root', type=Path, required=True)
    p.add_argument('--headers', type=Path, required=True)
    p.add_argument('--locale', required=True)
    p.add_argument('--out', type=Path, required=True, help='output root; writes ROOT/LOCALE/SET/file.png')
    p.add_argument('--set', dest='set_key')
    args = p.parse_args()
    data, headers = config(args.config), read_json(args.headers)[args.locale]
    sets = data['sets'] if args.set_key is None else {args.set_key: data['sets'][args.set_key]}
    for key, group in sets.items():
        frames = group['frames']
        jobs = []  # (frame index, role group, job)
        for i, f in enumerate(frames):
            head = headers[f['file']].split('\n')
            sub = headers[f['file'] + '#sub'].split('\n')
            for it in f['items']:
                lines = head if it['role'][0] == 'h' else sub
                n = int(it['role'][1:]) - 1
                if n >= len(lines):
                    continue
                jobs.append((i, it['role'][0], {'text': lines[n], 'locale': args.locale, 'font': it['font'], 'color': it['color'],
                             'box': it['box'][2:], 'maxSize': it['max_size'], 'minSize': 1, 'align': it.get('align', 'left'),
                             '_box': it['box']}))
        results = headline([{k: v for k, v in j.items() if k != '_box'} for _, _, j in jobs])
        for (i, g, j), r in zip(jobs, results):
            if not r['fits']:
                raise ValueError(f"{key}/{frames[i]['file']}: {j['text']!r} does not fit")
        sizes = {g: min(r['size'] for (_, gg, _), r in zip(jobs, results) if gg == g) for g in 'hs'}
        for g, minimum in (('h', 60), ('s', 30)):
            if sizes[g] < minimum:
                raise ValueError(f'{key}: {g} size {sizes[g]:g} below {minimum}')
        with tempfile.TemporaryDirectory() as tmp:
            final = [{k: v for k, v in j.items() if k != '_box'} | {'size': sizes[g], 'out': str(Path(tmp) / f'{n}.png')}
                     for n, (_, g, j) in enumerate(jobs)]
            rendered = headline(final)
            if not all(r['fits'] for r in rendered):
                raise ValueError(f'{key}: uniform size does not fit')
            output = args.out / args.locale / key
            output.mkdir(parents=True, exist_ok=True)
            for i, frame in enumerate(frames):
                with Image.open(source(data, frame['base'])) as im:
                    canvas = im.convert('RGB')
                erase_header(canvas, frame['header_box'], None)
                for target in destinations(frame):
                    rp = raw_path(args.raw_root, args.locale, key, target['raw'])
                    if not rp.is_file():
                        raise ValueError(f'missing raw {rp}')
                    with Image.open(rp) as raw:
                        paste_screen(canvas, raw, target['rect'], target.get('radius', 0))
                for n, (fi, g, j) in enumerate(jobs):
                    if fi == i:
                        with Image.open(final[n]['out']) as overlay:
                            canvas.paste(overlay, tuple(j['_box'][:2]), overlay)
                canvas.save(output / frame['file'], format='PNG', optimize=True)
            print(f"{args.locale}/{key}: {len(frames)} frames h={sizes['h']:g} s={sizes['s']:g}")


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        print(f'reskin: {error}', file=sys.stderr)
        sys.exit(1)
