#!/usr/bin/env python3
"""Attach the review screenshot to Queasy's subscriptions and lifetime IAP.

Usage: source ~/.baseball_credentials && python3 scripts/asc-review-screenshots.py <image.png>
"""

import hashlib
import json
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE = "com.jackwallner.queasy"


def upload_asset(c, create_path: str, owner_type: str, owner_key: str, owner_id: str, image: Path) -> None:
    data = image.read_bytes()
    md5 = hashlib.md5(data).hexdigest()
    reservation = c.post(
        create_path,
        {
            "data": {
                "type": create_path.strip("/"),
                "attributes": {"fileName": image.name, "fileSize": len(data)},
                "relationships": {
                    owner_key: {"data": {"type": owner_type, "id": owner_id}}
                },
            }
        },
    )["data"]
    for op in reservation["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]: op["offset"] + op["length"]]
        req = urllib.request.Request(
            op["url"],
            data=chunk,
            method=op["method"],
            headers={h["name"]: h["value"] for h in op["requestHeaders"]},
        )
        urllib.request.urlopen(req, timeout=120).read()
    c.patch(
        f"{create_path}/{reservation['id']}",
        {
            "data": {
                "type": create_path.strip("/"),
                "id": reservation["id"],
                "attributes": {"uploaded": True, "sourceFileChecksum": md5},
            }
        },
    )
    print(f"  uploaded + committed ({create_path})")


def main() -> None:
    image = Path(sys.argv[1])
    c = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(c, BUNDLE)

    group = c.get(f"/apps/{app['id']}/subscriptionGroups")["data"][0]
    for sub in c.get(f"/subscriptionGroups/{group['id']}/subscriptions")["data"]:
        pid = sub["attributes"]["productId"]
        try:
            existing = c.get(f"/subscriptions/{sub['id']}/appStoreReviewScreenshot")
            if existing.get("data"):
                print(f"{pid}: screenshot exists")
                continue
        except RuntimeError:
            pass
        print(f"{pid}: uploading")
        upload_asset(
            c,
            "/subscriptionAppStoreReviewScreenshots",
            "subscriptions",
            "subscription",
            sub["id"],
            image,
        )

    for iap in c.get(f"/apps/{app['id']}/inAppPurchasesV2")["data"]:
        pid = iap["attributes"]["productId"]
        asc_lib.API = "https://api.appstoreconnect.apple.com/v2"
        try:
            existing = c.get(f"/inAppPurchases/{iap['id']}/appStoreReviewScreenshot")
            if existing.get("data"):
                asc_lib.API = "https://api.appstoreconnect.apple.com/v1"
                print(f"{pid}: screenshot exists")
                continue
        except RuntimeError:
            pass
        asc_lib.API = "https://api.appstoreconnect.apple.com/v1"
        print(f"{pid}: uploading")
        upload_asset(
            c,
            "/inAppPurchaseAppStoreReviewScreenshots",
            "inAppPurchases",
            "inAppPurchaseV2",
            iap["id"],
            image,
        )

    print("done")


if __name__ == "__main__":
    main()
