#!/usr/bin/env python3
"""Put Queasy back on sale in every territory recorded in the availability backup.

Written for the 2026-07-30 delisting: the app shipped with three in-app
purchases that had never been approved, so the paywall was dead and the app
was pulled from sale while the IAPs went through review. Run this once the
submission is approved.

Usage: python3 scripts/asc-restore-availability.py [--dry-run]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from asc_lib import ASCClient, bearer_token, load_credentials

BACKUP = Path(__file__).parent / ".queasy-availability-backup.json"


def main() -> None:
    dry_run = "--dry-run" in sys.argv
    rows = json.loads(BACKUP.read_text())["rows"]
    client = ASCClient(bearer_token(*load_credentials()))

    print(f"restoring {len(rows)} territories" + (" (dry run)" if dry_run else ""))
    ok = 0
    failures: list[tuple[str, str]] = []
    for i, row in enumerate(rows):
        code = row["relationships"]["territory"]["data"]["id"]
        if dry_run:
            continue
        try:
            client.patch(
                f"/territoryAvailabilities/{row['id']}",
                {
                    "data": {
                        "type": "territoryAvailabilities",
                        "id": row["id"],
                        "attributes": {"available": True},
                    }
                },
            )
            ok += 1
        except Exception as exc:  # noqa: BLE001 - report and keep going
            failures.append((code, str(exc)[:120]))
        # Tokens are good for 20 minutes; refresh well inside that.
        if i % 40 == 39:
            client = ASCClient(bearer_token(*load_credentials()))

    print(f"restored: {ok}  failed: {len(failures)}")
    for code, err in failures:
        print(f"  {code}: {err}")


if __name__ == "__main__":
    main()
