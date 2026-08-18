#!/usr/bin/env python3
"""Apply purchasing-power-parity discounts to Queasy in emerging markets.

`asc-equalize-sub-prices.py` fills every territory at Apple's USD-parity
equalization. This script goes a step further, matching how Vitals prices:
pull specific lower-income markets DOWN to a target USD-equivalent ceiling so
the app is affordable where $4.99/mo is a lot of money.

Covers both subscriptions and the one-time lifetime unlock. Existing
subscribers keep their price (`preserveCurrentPrice=True`); only new sign-ups
after the scheduled start see the lower price.

Usage:
    source ~/.baseball_credentials && python3 scripts/asc-discount-emerging-markets.py
    DRY_RUN=1 python3 scripts/asc-discount-emerging-markets.py   # preview only
"""

import os
import sys
import time
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE = "com.jackwallner.queasy"
DRY_RUN = os.environ.get("DRY_RUN") == "1"
# Rerun-safety: subscription prices are additive scheduled changes, so set
# ONLY=lifetime (or ONLY=subs) to run just one half after a partial failure.
ONLY = os.environ.get("ONLY", "").lower()

# USA anchor prices, so the discounts read as a % off the home market.
USA = {"monthly": 4.99, "yearly": 29.99, "lifetime": 69.99}

# Per-territory USD-equivalent ceilings (monthly, yearly, lifetime). Tiers
# mirror the Vitals rollout: severe-gap ~ -65%, moderate ~ -45%, light ~ -25%.
TIERS = {
    # Severe-gap markets
    "IND": (1.99, 9.99, 24.99),   # India
    "PAK": (1.99, 9.99, 24.99),   # Pakistan
    "BGD": (1.99, 9.99, 24.99),   # Bangladesh
    "IDN": (1.99, 9.99, 24.99),   # Indonesia
    "VNM": (1.99, 9.99, 24.99),   # Vietnam
    "PHL": (1.99, 9.99, 24.99),   # Philippines
    "EGY": (1.99, 9.99, 24.99),   # Egypt
    "NGA": (1.99, 9.99, 24.99),   # Nigeria
    "LKA": (1.99, 9.99, 24.99),   # Sri Lanka
    "KEN": (1.99, 9.99, 24.99),   # Kenya
    # Moderate-gap markets
    "TUR": (2.99, 15.99, 39.99),  # Turkey
    "BRA": (2.99, 15.99, 39.99),  # Brazil
    "MEX": (2.99, 15.99, 39.99),  # Mexico
    "COL": (2.99, 15.99, 39.99),  # Colombia
    "CHL": (2.99, 15.99, 39.99),  # Chile
    "THA": (2.99, 15.99, 39.99),  # Thailand
    "MYS": (2.99, 15.99, 39.99),  # Malaysia
    "POL": (2.99, 15.99, 39.99),  # Poland
    "HUN": (2.99, 15.99, 39.99),  # Hungary
    "ROU": (2.99, 15.99, 39.99),  # Romania
    "ZAF": (2.99, 15.99, 39.99),  # South Africa
    "ARG": (2.99, 15.99, 39.99),  # Argentina
    # Light-gap markets
    "SAU": (3.99, 22.99, 54.99),  # Saudi Arabia
    "ARE": (3.99, 22.99, 54.99),  # UAE
    "CZE": (3.99, 22.99, 54.99),  # Czech Republic
    "GRC": (3.99, 22.99, 54.99),  # Greece
    "CHN": (3.99, 22.99, 54.99),  # China mainland
}

# ISO-3 → currency, then approx USD per 1 unit, to rank a territory's price
# points by USD-equivalent (only used for ranking, not billing).
TERRITORY_CURRENCY = {
    "IND": "INR", "PAK": "PKR", "BGD": "BDT", "IDN": "IDR", "VNM": "VND",
    "PHL": "PHP", "EGY": "EGP", "NGA": "NGN", "LKA": "LKR", "KEN": "KES",
    "TUR": "TRY", "BRA": "BRL", "MEX": "MXN", "COL": "COP", "CHL": "CLP",
    "THA": "THB", "MYS": "MYR", "POL": "PLN", "HUN": "HUF", "ROU": "RON",
    "ZAF": "ZAR", "ARG": "ARS", "SAU": "SAR", "ARE": "AED", "CZE": "CZK",
    "GRC": "EUR", "CHN": "CNY",
}
FX = {
    "INR": 0.012, "PKR": 0.0036, "BDT": 0.0082, "IDR": 0.000062, "VND": 0.0000395,
    "PHP": 0.0173, "EGP": 0.020, "NGN": 0.00065, "LKR": 0.0033, "KES": 0.0077,
    "TRY": 0.029, "BRL": 0.20, "MXN": 0.049, "COP": 0.00024, "CLP": 0.0011,
    "THB": 0.029, "MYR": 0.22, "PLN": 0.25, "HUF": 0.0028, "RON": 0.22,
    "ZAR": 0.055, "ARS": 0.0011, "SAR": 0.27, "AED": 0.27, "CZK": 0.044,
    "EUR": 1.08, "CNY": 0.14, "USD": 1.0,
}

# Apple requires an approved product's price change to be scheduled ahead.
SCHEDULED_START = (date.today() + timedelta(days=2)).isoformat()


def usd_eq(terr: str, customer_price: float) -> float:
    ccy = TERRITORY_CURRENCY.get(terr, "USD")
    return customer_price * FX.get(ccy, 1.0)


def pick_point(points: list, terr: str, target_usd: float):
    """Highest price point whose USD-equivalent is <= target; else the cheapest."""
    ranked = sorted(
        (usd_eq(terr, float(p["attributes"]["customerPrice"])),
         float(p["attributes"]["customerPrice"]), p["id"])
        for p in points
    )
    if not ranked:
        return None
    eligible = [r for r in ranked if r[0] <= target_usd]
    return (eligible[-1] if eligible else ranked[0])


# ------- subscriptions -------

def discount_subscriptions(c, app_id: str) -> int:
    group = c.get(f"/apps/{app_id}/subscriptionGroups")["data"][0]
    subs = c.get(f"/subscriptionGroups/{group['id']}/subscriptions")["data"]
    by_kind = {}
    for sub in subs:
        pid = sub["attributes"]["productId"]
        if pid.endswith(".monthly"):
            by_kind["monthly"] = sub["id"]
        elif pid.endswith(".yearly"):
            by_kind["yearly"] = sub["id"]

    applied = 0
    for kind, sub_id in by_kind.items():
        idx = {"monthly": 0, "yearly": 1}[kind]
        print(f"\n=== subscription: {kind} ({sub_id}) ===")
        for terr, targets in TIERS.items():
            target = targets[idx]
            pts = asc_lib.list_all(
                c, f"/subscriptions/{sub_id}/pricePoints?filter[territory]={terr}&limit=200"
            )
            pick = pick_point(pts, terr, target)
            if not pick:
                print(f"  {terr}: no price points")
                continue
            eq, cp, pp_id = pick
            print(f"  {terr}: -> {cp} {TERRITORY_CURRENCY.get(terr)} (~${eq:.2f}, <= ${target}, home ${USA[kind]})")
            if DRY_RUN:
                continue
            try:
                c.post("/subscriptionPrices", {
                    "data": {
                        "type": "subscriptionPrices",
                        "attributes": {"preserveCurrentPrice": True, "startDate": SCHEDULED_START},
                        "relationships": {
                            "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                            "territory": {"data": {"type": "territories", "id": terr}},
                            "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": pp_id}},
                        },
                    }
                })
                applied += 1
            except RuntimeError as e:
                print(f"    {terr}: post fail: {str(e)[:140]}", file=sys.stderr)
            time.sleep(0.15)
    return applied


# ------- lifetime IAP -------

def discount_lifetime(c, app_id: str) -> int:
    iaps = c.get(f"/apps/{app_id}/inAppPurchasesV2")["data"]
    iap = next((i for i in iaps if i["attributes"]["productId"].endswith(".lifetime")), None)
    if not iap:
        print("\n=== lifetime: no IAP found, skipping ===")
        return 0
    iap_id = iap["id"]
    print(f"\n=== lifetime IAP ({iap_id}) ===")

    # The lifetime price is a manual price schedule: one baseline (USA) plus a
    # list of manual per-territory prices. We rebuild the schedule with the
    # discounted points added alongside the USA baseline.
    asc_lib.API = "https://api.appstoreconnect.apple.com/v2"
    try:
        usa_pts = asc_lib.list_all(
            c, f"/inAppPurchases/{iap_id}/pricePoints?filter[territory]=USA&limit=200"
        )
        usa_point = next(
            (p for p in usa_pts if float(p["attributes"]["customerPrice"]) == USA["lifetime"]),
            None,
        )
        if not usa_point:
            print(f"  no USA ${USA['lifetime']} price point; skipping lifetime")
            return 0

        manual_prices = []
        # tempId-referenced baseline for USA.
        included = [{
            "type": "inAppPurchasePrices",
            "id": "${usa}",
            "attributes": {"startDate": None},
            "relationships": {
                "inAppPurchasePricePoint": {
                    "data": {"type": "inAppPurchasePricePoints", "id": usa_point["id"]}
                },
            },
        }]
        manual_prices.append({"type": "inAppPurchasePrices", "id": "${usa}"})

        for terr, targets in TIERS.items():
            target = targets[2]
            pts = asc_lib.list_all(
                c, f"/inAppPurchases/{iap_id}/pricePoints?filter[territory]={terr}&limit=200"
            )
            pick = pick_point(pts, terr, target)
            if not pick:
                print(f"  {terr}: no price points")
                continue
            eq, cp, pp_id = pick
            print(f"  {terr}: -> {cp} {TERRITORY_CURRENCY.get(terr)} (~${eq:.2f}, <= ${target}, home ${USA['lifetime']})")
            tmp = f"${{{terr}}}"
            included.append({
                "type": "inAppPurchasePrices",
                "id": tmp,
                "attributes": {"startDate": SCHEDULED_START},
                "relationships": {
                    "inAppPurchasePricePoint": {
                        "data": {"type": "inAppPurchasePricePoints", "id": pp_id}
                    },
                },
            })
            manual_prices.append({"type": "inAppPurchasePrices", "id": tmp})

        if DRY_RUN:
            return 0

        # The price-schedule mutation lives on v1; only the price-point reads
        # above are v2. Switch back before POSTing.
        asc_lib.API = "https://api.appstoreconnect.apple.com/v1"
        c.post("/inAppPurchasePriceSchedules", {
            "data": {
                "type": "inAppPurchasePriceSchedules",
                "relationships": {
                    "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                    "manualPrices": {"data": manual_prices},
                    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                },
            },
            "included": included,
        })
        print(f"  lifetime price schedule rebuilt with {len(manual_prices) - 1} discounts")
        return len(manual_prices) - 1
    finally:
        asc_lib.API = "https://api.appstoreconnect.apple.com/v1"


def main() -> None:
    if DRY_RUN:
        print("DRY RUN: previewing target prices, no changes will be posted.\n")
    c = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(c, BUNDLE)
    subs = discount_subscriptions(c, app["id"]) if ONLY in ("", "subs") else "skipped"
    life = discount_lifetime(c, app["id"]) if ONLY in ("", "lifetime") else "skipped"
    print(f"\nDone. Subscription prices: {subs}, lifetime discounts: {life}. Start: {SCHEDULED_START}")


if __name__ == "__main__":
    main()
