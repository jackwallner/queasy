#!/usr/bin/env python3
"""One gh-sim launch job for all locales and scenes; sorts shots into raw/<locale>/phone/."""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

KIT = Path(__file__).resolve().parent.parent
RESULTS = Path.home() / ".gh-sim/results"
BASELINE = {"store_locale": "en-US", "apple_languages": "(en)", "apple_locale": "en_US"}


def main() -> None:
    repo = Path(sys.argv[1])
    args = sys.argv[2:]
    reuse = None
    if "--from" in args:  # sort an existing run instead of launching: --from RUN_ID locale...
        i = args.index("--from")
        reuse = args[i + 1]
        args = args[:i] + args[i + 2:]
    nobase = "--no-baseline" in args  # skip the en-US baseline screens (raw/en-US already captured)
    args = [a for a in args if a != "--no-baseline"]
    want = args
    targets = json.loads((KIT / "app.json").read_text())["targets"]
    if want:
        targets = [t for t in targets if t["store_locale"] in want]
    scenes = json.loads((KIT / "tools/scenes.json").read_text())
    plan = []  # (locale, scene)
    cmd = ["gh-sim", "-C", str(repo), "launch", "--device", "iPhone 17 Pro Max", "--wait", "6",
           "--id-file", str(KIT / "last_run_id")]
    for t in ([] if nobase else [BASELINE]) + targets:
        for name, args in scenes.items():
            lang = f"-AppleLanguages {t['apple_languages']} -AppleLocale {t['apple_locale']}"
            cmd += ["--screen", f"{lang} {args}"]
            plan.append((t["store_locale"], name))
    if reuse:
        run_id = reuse
    else:
        subprocess.run(cmd, check=False)
        run_id = (KIT / "last_run_id").read_text().strip()
    by_index = {}
    for p in (RESULTS / run_id).glob("shots/screen*.png"):
        m = re.match(r"screen(\d+)-", p.name)
        if m:
            by_index[int(m.group(1))] = p
    print(f"run {run_id}: {len(by_index)} shots for {len(plan)} scenes")
    for n, (loc, name) in enumerate(plan, 1):
        if n not in by_index:
            print(f"missing {loc}/{name}")
            continue
        out = KIT / "raw" / loc / "phone"
        out.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(by_index[n], out / f"{name}.png")


if __name__ == "__main__":
    main()
