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
    want = sys.argv[2:]
    targets = json.loads((KIT / "app.json").read_text())["targets"]
    if want:
        targets = [t for t in targets if t["store_locale"] in want]
    scenes = json.loads((KIT / "tools/scenes.json").read_text())
    plan = []  # (locale, scene)
    cmd = ["gh-sim", "-C", str(repo), "launch", "--device", "iPhone 17 Pro Max", "--wait", "6",
           "--id-file", str(KIT / "last_run_id")]
    for t in [BASELINE] + targets:
        for name, args in scenes.items():
            lang = f"-AppleLanguages {t['apple_languages']} -AppleLocale {t['apple_locale']}"
            cmd += ["--screen", f"{lang} {args}"]
            plan.append((t["store_locale"], name))
    subprocess.run(cmd, check=False)
    run_id = (KIT / "last_run_id").read_text().strip()
    shots = sorted((RESULTS / run_id).glob("shots/*.png"), key=lambda p: [int(x) if x.isdigit() else x for x in re.split(r"(\d+)", p.name)])
    print(f"run {run_id}: {len(shots)} shots for {len(plan)} scenes")
    if len(shots) < len(plan):
        sys.exit("fewer shots than scenes; inspect the run")
    # gh-sim writes the base launch first when --args is empty? align from the tail.
    shots = shots[-len(plan):]
    for (loc, name), shot in zip(plan, shots):
        out = KIT / "raw" / loc / "phone"
        out.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(shot, out / f"{name}.png")


if __name__ == "__main__":
    main()
