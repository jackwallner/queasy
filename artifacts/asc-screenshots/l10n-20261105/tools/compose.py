#!/usr/bin/env python3
"""compose.py [store_locale ...]: reskin, sheet and gate every target, then copy PASSing sets to fastlane/screenshots."""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

KIT = Path(__file__).resolve().parent.parent
TOOLS = KIT / "tools"
REPO = KIT.parent.parent.parent
PY = sys.executable


def run(script: str, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run([PY, str(TOOLS / script), *args], text=True, capture_output=True, cwd=KIT)


def main() -> None:
    targets = json.loads((KIT / "app.json").read_text())["targets"]
    want = sys.argv[1:]
    if want:
        targets = [t for t in targets if t["store_locale"] in want]
    common = ["--config", "frames.json"]
    gates = {}
    for t in targets:
        loc = t["store_locale"]
        r = run("reskin.py", *common, "--raw-root", "raw", "--headers", "copy/headers.json", "--locale", loc, "--out", "out")
        print(r.stdout.strip() or r.stderr.strip())
        if r.returncode:
            gates[loc] = "FAIL (reskin)"
            continue
        run("sheet.py", *common, "--locale", loc, "--out-root", "out", "--base-label", "en")
        g = run("gate.py", *common, "--raw-root", "raw", "--headers", "copy/headers.json", "--out-root", "out",
                "--locale", loc, "--catalog", str(REPO / "Shared/Localizable.xcstrings"), "--lang", t["lang"])
        lines = g.stdout.strip().splitlines()
        gates[loc] = lines[-1] if lines else "FAIL"
        print(loc, gates[loc])
        for line in lines[:-1][:12]:
            print("  ", line)
        if gates[loc] == "PASS":
            dest = REPO / "fastlane/screenshots" / loc
            dest.mkdir(parents=True, exist_ok=True)
            for png in (KIT / "out" / loc / "phone").glob("*.png"):
                shutil.copyfile(png, dest / png.name)
    (KIT / "gate_status.json").write_text(json.dumps(gates, indent=1))


if __name__ == "__main__":
    main()
