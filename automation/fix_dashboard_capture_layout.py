#!/usr/bin/env python3
"""Fix mini-dashboard layout for clean full-page screenshots.

Runs after upgrade_mini_dashboards.py.

Fixes observed during live Power BI review:
- legacy KPI cards display their measure/category name below the value and the
  text can be clipped by the compact card height;
- shrinking the main visual to 505px introduced an internal scrollbar on Q01
  and creates the same risk on other dense ranking/category pages.

This pass hides duplicate card category labels, restores a 620px main visual,
and increases only the selected mini-dashboard page canvas to 800px. FitToPage
remains enabled, so the full dashboard can still be captured in one screenshot.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
REPORT_ROOTS = {
    "A": ROOT / "PROJECT" / "Version_A_PowerBI" / "BISM2202_Seed.Report",
    "B": ROOT / "PROJECT" / "Version_B_PowerBI" / "BISM2202_Seed.Report",
}
PAGES = {
    "q01": "q01_chart",
    "q04": "q04_chart",
    "q07": "q07_chart",
    "q09": "q09_chart",
    "q13": "q13_chart",
    "q15": "q15_chart",
}
PAGE_HEIGHT = 800
MAIN_Y = 145
MAIN_HEIGHT = 620
CARD_Y = 25
CARD_HEIGHT = 100


def lit(value: str) -> dict[str, Any]:
    return {"expr": {"Literal": {"Value": value}}}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, data: dict[str, Any]) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def patch_page(root: Path, page: str, main_name: str) -> int:
    page_root = root / "definition" / "pages" / page
    page_json = page_root / "page.json"
    page_data = load_json(page_json)
    page_data["height"] = PAGE_HEIGHT
    page_data["displayOption"] = "FitToPage"
    save_json(page_json, page_data)

    main_path = page_root / "visuals" / main_name / "visual.json"
    main = load_json(main_path)
    main.setdefault("position", {}).update({
        "x": 35,
        "y": MAIN_Y,
        "z": 0,
        "height": MAIN_HEIGHT,
        "width": 1210,
        "tabOrder": 10,
    })
    save_json(main_path, main)

    cards = 0
    for card_path in sorted((page_root / "visuals").glob(f"kpi_{page}_*/visual.json")):
        card = load_json(card_path)
        visual = card.get("visual", {})
        if visual.get("visualType") != "card":
            raise RuntimeError(f"{card_path}: expected legacy card visual")

        card.setdefault("position", {}).update({
            "y": CARD_Y,
            "height": CARD_HEIGHT,
        })
        objects = visual.setdefault("objects", {})
        objects["categoryLabels"] = [
            {"properties": {"show": lit("false")}}
        ]
        labels = objects.setdefault("labels", [{"properties": {}}])
        if not labels:
            labels.append({"properties": {}})
        labels[0].setdefault("properties", {})["fontSize"] = lit("26D")
        save_json(card_path, card)
        cards += 1

    if cards != 3:
        raise RuntimeError(f"{page}: expected 3 KPI cards, found {cards}")
    return cards


def validate_version(version: str) -> None:
    root = REPORT_ROOTS[version]
    card_count = 0
    for page, main_name in PAGES.items():
        page_root = root / "definition" / "pages" / page
        page_data = load_json(page_root / "page.json")
        if page_data.get("height") != PAGE_HEIGHT or page_data.get("displayOption") != "FitToPage":
            raise RuntimeError(f"Version {version} {page}: page sizing validation failed")

        main = load_json(page_root / "visuals" / main_name / "visual.json")
        pos = main.get("position", {})
        if pos.get("y") != MAIN_Y or pos.get("height") != MAIN_HEIGHT:
            raise RuntimeError(f"Version {version} {page}: main visual sizing validation failed")

        for card_path in sorted((page_root / "visuals").glob(f"kpi_{page}_*/visual.json")):
            card = load_json(card_path)
            pos = card.get("position", {})
            if pos.get("y") != CARD_Y or pos.get("height") != CARD_HEIGHT:
                raise RuntimeError(f"Version {version} {page}: card sizing validation failed")
            category_labels = card.get("visual", {}).get("objects", {}).get("categoryLabels", [])
            try:
                show = category_labels[0]["properties"]["show"]["expr"]["Literal"]["Value"]
            except (KeyError, IndexError, TypeError):
                raise RuntimeError(f"Version {version} {page}: category label visibility validation failed")
            if show != "false":
                raise RuntimeError(f"Version {version} {page}: duplicate KPI category label is still visible")
            card_count += 1

    if card_count != 18:
        raise RuntimeError(f"Version {version}: expected 18 KPI cards, found {card_count}")


def patch_version(version: str) -> None:
    root = REPORT_ROOTS[version]
    if not root.exists():
        raise FileNotFoundError(root)
    total = 0
    for page, main_name in PAGES.items():
        total += patch_page(root, page, main_name)
    validate_version(version)
    print(f"Version {version}: 6 dashboard pages resized for full-page capture PASS")
    print(f"Version {version}: {total} KPI duplicate category labels hidden PASS")
    print(f"Version {version}: dense main visuals restored to 620px height PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", choices=["A", "B", "Both"], default="Both")
    args = parser.parse_args()
    versions = ["A", "B"] if args.version == "Both" else [args.version]
    for version in versions:
        patch_version(version)
    print("DASHBOARD_CAPTURE_LAYOUT_FIX: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
