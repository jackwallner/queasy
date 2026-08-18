#!/usr/bin/env python3
"""Push only name/subtitle/keywords/promotionalText from fastlane/metadata to ASC.

Why not `fastlane deliver`: deliver pushes the whole listing, which drags in the
two traps recorded against this app. It re-uploads screenshots (leaving
duplicates even with --overwrite_screenshots) and it re-sends App Review
Information, where a review-notes field over 4000 characters fails the entire
step after every locale has already been written. When the only change is the
indexed text, this touches only the indexed text.

Name and subtitle live on appInfoLocalizations; keywords and promotional text
live on appStoreVersionLocalizations. Both need their parent in an editable
state, so pull the version from review first if it is waiting.

    python3 scripts/asc-push-listing-fields.py            # push
    python3 scripts/asc-push-listing-fields.py --dry-run  # diff only
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import asc_lib as A  # noqa: E402

INFO_FIELDS = {"name": "name.txt", "subtitle": "subtitle.txt"}
VERSION_FIELDS = {
    "keywords": "keywords.txt",
    "promotionalText": "promotional_text.txt",
}


def read(locale: str, filename: str) -> str | None:
    path = A.META / locale / filename
    return path.read_text().strip() if path.exists() else None


def push(client, endpoint, kind, fields, dry_run):
    changed = 0
    for row in A.list_all(client, endpoint):
        locale = row["attributes"]["locale"]
        patch = {}
        for field, filename in fields.items():
            wanted = read(locale, filename)
            if wanted is None or wanted == (row["attributes"].get(field) or "").strip():
                continue
            patch[field] = wanted
        if not patch:
            continue
        changed += 1
        for field, value in patch.items():
            before = (row["attributes"].get(field) or "").strip()
            print(f"  {locale:<8} {field:<16} {before!r}\n           {'':<16} -> {value!r}")
        if not dry_run:
            client.patch(
                f"/{kind}/{row['id']}",
                {"data": {"type": kind, "id": row["id"], "attributes": patch}},
            )
    return changed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default=None, help="version string (default: editable one)")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    client = A.ASCClient(A.bearer_token(*A.load_credentials()))
    app = A.find_app(client, A.bundle_id_from_appfile())
    app_id = app["id"]

    version = (
        A.find_version_by_string(client, app_id, args.version)
        if args.version
        else A.find_editable_version(client, app_id)
    )
    if not version:
        raise SystemExit("error: no editable version. Pull it from review first.")
    info = A.find_editable_app_info(client, app_id)
    if not info:
        raise SystemExit("error: no editable appInfo. Pull it from review first.")

    print(f"version {version['attributes']['versionString']} "
          f"({version['attributes']['appStoreState']})")

    print("name / subtitle:")
    n = push(client, f"/appInfos/{info['id']}/appInfoLocalizations",
             "appInfoLocalizations", INFO_FIELDS, args.dry_run)
    print("keywords / promotional text:")
    v = push(client, f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations",
             "appStoreVersionLocalizations", VERSION_FIELDS, args.dry_run)

    verb = "would update" if args.dry_run else "updated"
    print(f"\n{verb}: {n} appInfo locales, {v} version locales")
    return 0


if __name__ == "__main__":
    sys.exit(main())
