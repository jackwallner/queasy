#!/usr/bin/env python3
"""One-shot (idempotent) ASC release setup for Queasy.

Creates/repairs: categories, age rating, subscription group + monthly/yearly
subscriptions (prices, yearly 1-week free trial, availability, localizations),
lifetime non-consumable (price schedule, availability, localization), and the
version review detail. Safe to rerun; each step checks before creating.

Usage: source ~/.baseball_credentials && python3 scripts/asc-setup-release.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE = "com.jackwallner.queasy"
GROUP_NAME = "Queasy Pro"
SUBS = [
    {
        "productId": "com.jackwallner.queasy.pro.monthly",
        "name": "Queasy Pro Monthly",
        "period": "ONE_MONTH",
        "price": "4.99",
        "desc": "All Queasy Pro features, billed monthly.",
        "trial": True,
    },
    {
        "productId": "com.jackwallner.queasy.pro.yearly",
        "name": "Queasy Pro Yearly",
        "period": "ONE_YEAR",
        "price": "29.99",
        "desc": "All Queasy Pro features, billed yearly.",
        "trial": True,
    },
]
LIFETIME = {
    "productId": "com.jackwallner.queasy.pro.lifetime",
    "name": "Queasy Pro Lifetime",
    "price": "69.99",
    "desc": "All Queasy Pro features forever. Pay once.",
}
REVIEW_NOTES = """- No account or login is required.
- On first launch a short onboarding explains the app, then the paywall gates the main experience (subscription or lifetime purchase; a 1-week free trial is available on the monthly and yearly plans).
- The main flow: answer a 3-question symptom check-in, receive a recommended vibration pattern, run it on the Apple Watch (background haptic session) or on the iPhone with its haptics.
- The Apple Watch app runs a physical-therapy extended runtime session so haptic pulses continue with the screen off; it also works standalone.
- The app is a drug-free comfort aid and makes no medical claims; disclaimers appear in onboarding, the Learn tab, and Settings.
- The optional 100 Hz tone in phone sessions uses the audio background mode.
- The app does not use non-exempt encryption."""


def main() -> None:
    c = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(c, BUNDLE)
    app_id = app["id"]
    print(f"app {app_id}")

    # --- categories + age rating on the editable appInfo ---
    infos = c.get(f"/apps/{app_id}/appInfos")["data"]
    for info in infos:
        state = info["attributes"].get("appStoreState") or info["attributes"].get("state")
        if state not in asc_lib.EDITABLE_STATES:
            continue
        c.patch(
            f"/appInfos/{info['id']}",
            {
                "data": {
                    "type": "appInfos",
                    "id": info["id"],
                    "relationships": {
                        "primaryCategory": {"data": {"type": "appCategories", "id": "HEALTH_AND_FITNESS"}},
                        "secondaryCategory": {"data": {"type": "appCategories", "id": "MEDICAL"}},
                    },
                }
            },
        )
        print("categories set")
        decl = c.get(f"/appInfos/{info['id']}/ageRatingDeclaration")["data"]
        # Full questionnaire, mirrored from the live headaches app: everything
        # NONE/false except healthOrWellnessTopics.
        age_attrs = {
            "advertising": False,
            "alcoholTobaccoOrDrugUseOrReferences": "NONE",
            "contests": "NONE",
            "gambling": False,
            "gamblingSimulated": "NONE",
            "gunsOrOtherWeapons": "NONE",
            "healthOrWellnessTopics": True,
            "lootBox": False,
            "medicalOrTreatmentInformation": "NONE",
            "messagingAndChat": False,
            "parentalControls": False,
            "profanityOrCrudeHumor": "NONE",
            "ageAssurance": False,
            "sexualContentGraphicAndNudity": "NONE",
            "sexualContentOrNudity": "NONE",
            "horrorOrFearThemes": "NONE",
            "matureOrSuggestiveThemes": "NONE",
            "unrestrictedWebAccess": False,
            "userGeneratedContent": False,
            "violenceCartoonOrFantasy": "NONE",
            "violenceRealisticProlongedGraphicOrSadistic": "NONE",
            "violenceRealistic": "NONE",
        }
        c.patch(
            f"/ageRatingDeclarations/{decl['id']}",
            {
                "data": {
                    "type": "ageRatingDeclarations",
                    "id": decl["id"],
                    "attributes": age_attrs,
                }
            },
        )
        print("age rating set (full questionnaire, healthOrWellnessTopics=true)")

    territories = [t["id"] for t in asc_lib.list_all(c, "/territories?limit=200")]
    print(f"{len(territories)} territories")

    # --- subscription group ---
    groups = c.get(f"/apps/{app_id}/subscriptionGroups")["data"]
    group = next((g for g in groups if g["attributes"]["referenceName"] == GROUP_NAME), None)
    if not group:
        group = c.post(
            "/subscriptionGroups",
            {
                "data": {
                    "type": "subscriptionGroups",
                    "attributes": {"referenceName": GROUP_NAME},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
        )["data"]
        print("group created")
    group_id = group["id"]

    glocs = c.get(f"/subscriptionGroups/{group_id}/subscriptionGroupLocalizations")["data"]
    if not any(l["attributes"]["locale"] == "en-US" for l in glocs):
        c.post(
            "/subscriptionGroupLocalizations",
            {
                "data": {
                    "type": "subscriptionGroupLocalizations",
                    "attributes": {"locale": "en-US", "name": GROUP_NAME, "customAppName": "Queasy"},
                    "relationships": {
                        "subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": group_id}}
                    },
                }
            },
        )
        print("group localization added")

    existing_subs = {
        s["attributes"]["productId"]: s
        for s in c.get(f"/subscriptionGroups/{group_id}/subscriptions")["data"]
    }

    for spec in SUBS:
        sub = existing_subs.get(spec["productId"])
        if not sub:
            sub = c.post(
                "/subscriptions",
                {
                    "data": {
                        "type": "subscriptions",
                        "attributes": {
                            "name": spec["name"],
                            "productId": spec["productId"],
                            "subscriptionPeriod": spec["period"],
                            "familySharable": False,
                            "groupLevel": 1,
                            "reviewNote": "Unlocks all Queasy Pro features (relief sessions, history).",
                        },
                        "relationships": {
                            "group": {"data": {"type": "subscriptionGroups", "id": group_id}}
                        },
                    }
                },
            )["data"]
            print(f"subscription created: {spec['productId']}")
        sub_id = sub["id"]

        locs = c.get(f"/subscriptions/{sub_id}/subscriptionLocalizations")["data"]
        if not any(l["attributes"]["locale"] == "en-US" for l in locs):
            c.post(
                "/subscriptionLocalizations",
                {
                    "data": {
                        "type": "subscriptionLocalizations",
                        "attributes": {"locale": "en-US", "name": spec["name"], "description": spec["desc"]},
                        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub_id}}},
                    }
                },
            )
            print(f"  localization added")

        try:
            c.get(f"/subscriptions/{sub_id}/subscriptionAvailability")
            print("  availability exists")
        except RuntimeError:
            c.post(
                "/subscriptionAvailabilities",
                {
                    "data": {
                        "type": "subscriptionAvailabilities",
                        "attributes": {"availableInNewTerritories": True},
                        "relationships": {
                            "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                            "availableTerritories": {
                                "data": [{"type": "territories", "id": t} for t in territories]
                            },
                        },
                    }
                },
            )
            print("  availability set (all territories)")

        prices = c.get(f"/subscriptions/{sub_id}/prices?limit=1")["data"]
        if not prices:
            points = asc_lib.list_all(
                c, f"/subscriptions/{sub_id}/pricePoints?filter[territory]=USA&limit=200"
            )
            point = next(
                (p for p in points if p["attributes"]["customerPrice"] == spec["price"]), None
            )
            if not point:
                raise SystemExit(f"no USA price point {spec['price']} for {spec['productId']}")
            c.post(
                "/subscriptionPrices",
                {
                    "data": {
                        "type": "subscriptionPrices",
                        "relationships": {
                            "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                            "subscriptionPricePoint": {
                                "data": {"type": "subscriptionPricePoints", "id": point["id"]}
                            },
                        },
                    }
                },
            )
            print(f"  price set ${spec['price']} (USA base, auto-equalized)")

        if spec["trial"]:
            # Intro offers are per-territory; create the free trial everywhere
            # it doesn't already exist.
            existing_offers = asc_lib.list_all(
                c, f"/subscriptions/{sub_id}/introductoryOffers?include=territory&limit=200"
            )
            covered = set()
            for o in existing_offers:
                terr = (o.get("relationships", {}).get("territory", {}).get("data") or {}).get("id")
                if terr:
                    covered.add(terr)
            missing = [t for t in territories if t not in covered]
            for t in missing:
                c.post(
                    "/subscriptionIntroductoryOffers",
                    {
                        "data": {
                            "type": "subscriptionIntroductoryOffers",
                            "attributes": {
                                "duration": "ONE_WEEK",
                                "offerMode": "FREE_TRIAL",
                                "numberOfPeriods": 1,
                            },
                            "relationships": {
                                "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                                "territory": {"data": {"type": "territories", "id": t}},
                            },
                        }
                    },
                )
            if missing:
                print(f"  1-week free trial added in {len(missing)} territories")


    # --- lifetime non-consumable ---
    iaps = c.get(f"/apps/{app_id}/inAppPurchasesV2")["data"]
    iap = next((i for i in iaps if i["attributes"]["productId"] == LIFETIME["productId"]), None)
    if not iap:
        # Creation lives on the v2 API; asc_lib is pinned to /v1.
        asc_lib.API = "https://api.appstoreconnect.apple.com/v2"
        iap = c.post(
            "/inAppPurchases",
            {
                "data": {
                    "type": "inAppPurchases",
                    "attributes": {
                        "name": LIFETIME["name"],
                        "productId": LIFETIME["productId"],
                        "inAppPurchaseType": "NON_CONSUMABLE",
                        "reviewNote": "One-time purchase that unlocks all Queasy Pro features forever.",
                    },
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
        )["data"]
        asc_lib.API = "https://api.appstoreconnect.apple.com/v1"
        print("lifetime IAP created")
    iap_id = iap["id"]

    asc_lib.API = "https://api.appstoreconnect.apple.com/v2"
    locs = c.get(f"/inAppPurchases/{iap_id}/inAppPurchaseLocalizations")["data"]
    asc_lib.API = "https://api.appstoreconnect.apple.com/v1"
    if not any(l["attributes"]["locale"] == "en-US" for l in locs):
        c.post(
            "/inAppPurchaseLocalizations",
            {
                "data": {
                    "type": "inAppPurchaseLocalizations",
                    "attributes": {"locale": "en-US", "name": LIFETIME["name"], "description": LIFETIME["desc"]},
                    "relationships": {
                        "inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}}
                    },
                }
            },
        )
        print("  localization added")

    try:
        asc_lib.API = "https://api.appstoreconnect.apple.com/v2"
        sched = c.get(f"/inAppPurchases/{iap_id}/iapPriceSchedule")
        asc_lib.API = "https://api.appstoreconnect.apple.com/v1"
        print("  price schedule exists")
    except RuntimeError:
        asc_lib.API = "https://api.appstoreconnect.apple.com/v2"
        points = asc_lib.list_all(
            c, f"/inAppPurchases/{iap_id}/pricePoints?filter[territory]=USA&limit=200"
        )
        asc_lib.API = "https://api.appstoreconnect.apple.com/v1"
        point = next((p for p in points if p["attributes"]["customerPrice"] == LIFETIME["price"]), None)
        if not point:
            raise SystemExit(f"no USA price point {LIFETIME['price']} for lifetime")
        c.post(
            "/inAppPurchasePriceSchedules",
            {
                "data": {
                    "type": "inAppPurchasePriceSchedules",
                    "relationships": {
                        "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                        "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                        "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${price0}"}]},
                    },
                },
                "included": [
                    {
                        "type": "inAppPurchasePrices",
                        "id": "${price0}",
                        "attributes": {"startDate": None},
                        "relationships": {
                            "inAppPurchasePricePoint": {
                                "data": {"type": "inAppPurchasePricePoints", "id": point["id"]}
                            }
                        },
                    }
                ],
            },
        )
        print(f"  price set ${LIFETIME['price']} (USA base)")

    try:
        asc_lib.API = "https://api.appstoreconnect.apple.com/v2"
        c.get(f"/inAppPurchases/{iap_id}/inAppPurchaseAvailability")
        asc_lib.API = "https://api.appstoreconnect.apple.com/v1"
        print("  availability exists")
    except RuntimeError:
        asc_lib.API = "https://api.appstoreconnect.apple.com/v1"
        c.post(
            "/inAppPurchaseAvailabilities",
            {
                "data": {
                    "type": "inAppPurchaseAvailabilities",
                    "attributes": {"availableInNewTerritories": True},
                    "relationships": {
                        "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                        "availableTerritories": {
                            "data": [{"type": "territories", "id": t} for t in territories]
                        },
                    },
                }
            },
        )
        print("  availability set (all territories)")

    # --- version review detail ---
    version = asc_lib.find_version_by_string(c, app_id, "1.0")
    if version:
        # NOTE: this endpoint returns {"data": null} (no HTTP error) when the
        # detail doesn't exist yet, so check the payload, not the status.
        rd = c.get(f"/appStoreVersions/{version['id']}/appStoreReviewDetail").get("data")
        if rd:
            print("review detail exists")
        else:
            c.post(
                "/appStoreReviewDetails",
                {
                    "data": {
                        "type": "appStoreReviewDetails",
                        "attributes": {
                            "contactFirstName": "Jack",
                            "contactLastName": "Wallner",
                            "contactPhone": "14257533411",
                            "contactEmail": "jackwallner+queasy@gmail.com",
                            "demoAccountRequired": False,
                            "notes": REVIEW_NOTES,
                        },
                        "relationships": {
                            "appStoreVersion": {
                                "data": {"type": "appStoreVersions", "id": version["id"]}
                            }
                        },
                    }
                },
            )
            print("review detail created")

    print("done")


if __name__ == "__main__":
    main()
