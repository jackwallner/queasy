#!/usr/bin/env python3
"""Add subscription-group + subscription localizations for every app locale.

Group name and product names stay "Queasy Pro …" everywhere; the one-line
descriptions are translated for major locales and fall back to English.

Usage: source ~/.baseball_credentials && python3 scripts/asc-localize-subs.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE = "com.jackwallner.queasy"

LOCALES = [
    "ar-SA", "bn-BD", "ca", "cs", "da", "de-DE", "el", "en-AU", "en-CA",
    "en-GB", "en-US", "es-ES", "es-MX", "fi", "fr-CA", "fr-FR", "gu-IN", "he",
    "hi", "hr", "hu", "id", "it", "ja", "kn-IN", "ko", "ml-IN", "mr-IN", "ms",
    "nl-NL", "no", "or-IN", "pa-IN", "pl", "pt-BR", "pt-PT", "ro", "ru", "sk",
    "sl-SI", "sv", "ta-IN", "te-IN", "th", "tr", "uk", "ur-PK", "vi",
    "zh-Hans", "zh-Hant",
]

# locale -> (monthly desc, yearly desc)
DESC = {
    "de-DE": ("Alle Queasy Pro Funktionen, monatlich.", "Alle Queasy Pro Funktionen, jährlich."),
    "fr-FR": ("Toutes les fonctions Queasy Pro, par mois.", "Toutes les fonctions Queasy Pro, par an."),
    "fr-CA": ("Toutes les fonctions Queasy Pro, par mois.", "Toutes les fonctions Queasy Pro, par an."),
    "es-ES": ("Todas las funciones de Queasy Pro, al mes.", "Todas las funciones de Queasy Pro, al año."),
    "es-MX": ("Todas las funciones de Queasy Pro, al mes.", "Todas las funciones de Queasy Pro, al año."),
    "it": ("Tutte le funzioni di Queasy Pro, mensile.", "Tutte le funzioni di Queasy Pro, annuale."),
    "pt-BR": ("Todos os recursos do Queasy Pro, mensal.", "Todos os recursos do Queasy Pro, anual."),
    "pt-PT": ("Todas as funções do Queasy Pro, mensal.", "Todas as funções do Queasy Pro, anual."),
    "ja": ("Queasy Proの全機能。月額プラン。", "Queasy Proの全機能。年額プラン。"),
    "ko": ("Queasy Pro 모든 기능, 월간 결제.", "Queasy Pro 모든 기능, 연간 결제."),
    "zh-Hans": ("Queasy Pro 全部功能，按月订阅。", "Queasy Pro 全部功能，按年订阅。"),
    "zh-Hant": ("Queasy Pro 全部功能，按月訂閱。", "Queasy Pro 全部功能，按年訂閱。"),
    "nl-NL": ("Alle Queasy Pro functies, per maand.", "Alle Queasy Pro functies, per jaar."),
    "sv": ("Alla Queasy Pro funktioner, per månad.", "Alla Queasy Pro funktioner, per år."),
    "tr": ("Tüm Queasy Pro özellikleri, aylık.", "Tüm Queasy Pro özellikleri, yıllık."),
    "ru": ("Все функции Queasy Pro, помесячно.", "Все функции Queasy Pro, ежегодно."),
    "pl": ("Wszystkie funkcje Queasy Pro, miesięcznie.", "Wszystkie funkcje Queasy Pro, rocznie."),
    "uk": ("Усі функції Queasy Pro, щомісяця.", "Усі функції Queasy Pro, щороку."),
}
DEFAULT = ("All Queasy Pro features, billed monthly.", "All Queasy Pro features, billed yearly.")


def main() -> None:
    c = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(c, BUNDLE)
    group = c.get(f"/apps/{app['id']}/subscriptionGroups")["data"][0]

    have = {
        l["attributes"]["locale"]
        for l in asc_lib.list_all(
            c, f"/subscriptionGroups/{group['id']}/subscriptionGroupLocalizations?limit=50"
        )
    }
    added = 0
    for locale in LOCALES:
        if locale in have:
            continue
        c.post(
            "/subscriptionGroupLocalizations",
            {
                "data": {
                    "type": "subscriptionGroupLocalizations",
                    "attributes": {"locale": locale, "name": "Queasy Pro", "customAppName": "Queasy"},
                    "relationships": {
                        "subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": group["id"]}}
                    },
                }
            },
        )
        added += 1
    print(f"group localizations added: {added}")

    for sub in c.get(f"/subscriptionGroups/{group['id']}/subscriptions")["data"]:
        pid = sub["attributes"]["productId"]
        idx = 0 if pid.endswith("monthly") else 1
        name = "Queasy Pro Monthly" if idx == 0 else "Queasy Pro Yearly"
        have = {
            l["attributes"]["locale"]
            for l in asc_lib.list_all(
                c, f"/subscriptions/{sub['id']}/subscriptionLocalizations?limit=50"
            )
        }
        added = 0
        for locale in LOCALES:
            if locale in have:
                continue
            desc = DESC.get(locale, DEFAULT)[idx]
            c.post(
                "/subscriptionLocalizations",
                {
                    "data": {
                        "type": "subscriptionLocalizations",
                        "attributes": {"locale": locale, "name": name, "description": desc},
                        "relationships": {
                            "subscription": {"data": {"type": "subscriptions", "id": sub["id"]}}
                        },
                    }
                },
            )
            added += 1
        print(f"{pid}: localizations added: {added}")

    print("done")


if __name__ == "__main__":
    main()
