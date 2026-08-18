#!/usr/bin/env python3
"""Wait for a TestFlight build to finish processing, then attach it to the
draft App Store version and set export compliance if needed.

Usage: source ~/.baseball_credentials && python3 scripts/asc-attach-build.py <buildNumber>
"""

import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE = "com.jackwallner.queasy"


def main() -> None:
    build_number = sys.argv[1]
    c = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(c, BUNDLE)
    # The version string used to be hardcoded to "1.0", which silently attached
    # every build to the first release. Take it from the environment, then the
    # state file, then whatever draft is editable.
    wanted = os.environ.get("ASC_APP_VERSION") or asc_lib.load_state().get("draftVersion")
    version = asc_lib.find_version_by_string(c, app["id"], wanted) if wanted else None
    version = version or asc_lib.find_editable_version(c, app["id"])
    if not version:
        raise SystemExit("error: no editable App Store version to attach to")
    version_string = version["attributes"]["versionString"]

    build = None
    deadline = time.time() + 45 * 60
    while time.time() < deadline:
        builds = c.get(
            f"/builds?filter[app]={app['id']}&filter[version]={build_number}&limit=5"
        )["data"]
        if builds:
            build = builds[0]
            state = build["attributes"]["processingState"]
            print(f"build {build['id']} state={state}", flush=True)
            if state == "VALID":
                break
            if state in ("FAILED", "INVALID"):
                raise SystemExit(f"build processing failed: {state}")
        else:
            print("build not visible yet", flush=True)
        time.sleep(60)
        # Token expires after 20 min; refresh each loop.
        c.token = asc_lib.bearer_token(*asc_lib.load_credentials())
    if not build or build["attributes"]["processingState"] != "VALID":
        raise SystemExit("timed out waiting for build")

    # ITSAppUsesNonExemptEncryption=false is in the Info.plist, so no
    # compliance questions should be pending; belt and braces anyway:
    if build["attributes"].get("usesNonExemptEncryption") is None:
        c.patch(
            f"/builds/{build['id']}",
            {"data": {"type": "builds", "id": build["id"], "attributes": {"usesNonExemptEncryption": False}}},
        )
        print("export compliance set (non-exempt: false)")

    c.patch(
        f"/appStoreVersions/{version['id']}",
        {
            "data": {
                "type": "appStoreVersions",
                "id": version["id"],
                "relationships": {"build": {"data": {"type": "builds", "id": build["id"]}}},
            }
        },
    )
    print(f"build {build_number} attached to version {version_string}")


if __name__ == "__main__":
    main()
