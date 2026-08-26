#!/usr/bin/env python3
"""Create richer mini-dashboard layouts for selected BISM2202 pages.

This pass is intentionally conservative:
- it preserves each question's existing main visual and measure bindings;
- it adds three KPI cards above the main visual on selected pages;
- it injects only helper KPI measures into the local semantic model;
- it does not save/export PBIX;
- it is idempotent and safe to rerun with Power BI closed.

Selected pages: Q01, Q04, Q07, Q09, Q13, Q15.
Q20 already contains three visuals and is left structurally intact.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import uuid
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
REPORT_ROOTS = {
    "A": ROOT / "PROJECT" / "Version_A_PowerBI" / "BISM2202_Seed.Report",
    "B": ROOT / "PROJECT" / "Version_B_PowerBI" / "BISM2202_Seed.Report",
}
MODEL_TABLES = {
    "A": ROOT / "PROJECT" / "Version_A_PowerBI" / "BISM2202_Seed.SemanticModel" / "definition" / "tables" / "PizzaOrders.tmdl",
    "B": ROOT / "PROJECT" / "Version_B_PowerBI" / "BISM2202_Seed.SemanticModel" / "definition" / "tables" / "PizzaOrders.tmdl",
}

PALETTES = {
    "A": ["#2F80ED", "#27AE60", "#F2994A"],
    "B": ["#457B9D", "#2A9D8F", "#E76F51"],
}

KPI_MEASURES: list[tuple[str, str, str]] = [
    ("Total Orders KPI", "[Order Count]", "#,0"),
    ("Unique Locations KPI", "DISTINCTCOUNT(PizzaOrders[Location])", "#,0"),
    ("Top Location Orders KPI", "MAXX(VALUES(PizzaOrders[Location]), CALCULATE([Order Count]))", "#,0"),
    ("Payment Methods KPI", "DISTINCTCOUNT(PizzaOrders[Payment Method])", "#,0"),
    ("Top Payment Orders KPI", "MAXX(VALUES(PizzaOrders[Payment Method]), CALCULATE([Order Count]))", "#,0"),
    ("Highest Avg Delivery KPI", "MAXX(VALUES(PizzaOrders[Location]), CALCULATE([Avg Delivery Duration]))", "0.00"),
    ("Locations at Max Delivery KPI", "VAR M = [Highest Avg Delivery KPI] RETURN COUNTROWS(FILTER(VALUES(PizzaOrders[Location]), ABS(CALCULATE([Avg Delivery Duration]) - M) < 0.000001))", "#,0"),
    ("Overall Avg Delivery KPI", "[Avg Delivery Duration]", "0.00"),
    ("Peak Month Orders KPI", "MAXX(VALUES(PizzaOrders[Order Month Start]), CALCULATE([Order Count]))", "#,0"),
    ("Avg Monthly Orders KPI", "AVERAGEX(VALUES(PizzaOrders[Order Month Start]), CALCULATE([Order Count]))", "0.00"),
    ("Latest Month Orders KPI", "VAR LatestMonth = MAX(PizzaOrders[Order Month Start]) RETURN CALCULATE([Order Count], PizzaOrders[Order Month Start] = LatestMonth)", "#,0"),
    ("Peak Hour Orders KPI", "MAXX(VALUES(PizzaOrders[Order Hour]), CALCULATE([Order Count]))", "#,0"),
    ("Peak Window Orders KPI", "CALCULATE([Order Count], FILTER(ALL(PizzaOrders[Order Hour]), PizzaOrders[Order Hour] >= 18 && PizzaOrders[Order Hour] <= 20))", "#,0"),
    ("Active Hours KPI", "COUNTROWS(FILTER(VALUES(PizzaOrders[Order Hour]), CALCULATE([Order Count]) > 0))", "#,0"),
    ("Dominant Complexity Share KPI", "MAXX(VALUES(PizzaOrders[Pizza Complexity]), CALCULATE([Order Share Overall]))", "0.00%"),
    ("Complexity Levels KPI", "DISTINCTCOUNT(PizzaOrders[Pizza Complexity])", "#,0"),
    ("Avg Complexity KPI", "AVERAGE(PizzaOrders[Pizza Complexity])", "0.00"),
]

PAGE_CARDS: dict[str, list[tuple[str, str]]] = {
    "q01": [
        ("Total Orders", "Total Orders KPI"),
        ("Unique Locations", "Unique Locations KPI"),
        ("Top Location Orders", "Top Location Orders KPI"),
    ],
    "q04": [
        ("Total Orders", "Total Orders KPI"),
        ("Payment Methods", "Payment Methods KPI"),
        ("Top Method Orders", "Top Payment Orders KPI"),
    ],
    "q07": [
        ("Highest Avg Duration", "Highest Avg Delivery KPI"),
        ("Locations at Maximum", "Locations at Max Delivery KPI"),
        ("Overall Avg Duration", "Overall Avg Delivery KPI"),
    ],
    "q09": [
        ("Peak Month Orders", "Peak Month Orders KPI"),
        ("Average Monthly Orders", "Avg Monthly Orders KPI"),
        ("Latest Partial Month", "Latest Month Orders KPI"),
    ],
    "q13": [
        ("Peak Hour Orders", "Peak Hour Orders KPI"),
        ("18:00 to 20:00 Orders", "Peak Window Orders KPI"),
        ("Active Order Hours", "Active Hours KPI"),
    ],
    "q15": [
        ("Largest Complexity Share", "Dominant Complexity Share KPI"),
        ("Complexity Levels", "Complexity Levels KPI"),
        ("Average Complexity", "Avg Complexity KPI"),
    ],
}

MAIN_VISUALS = {
    "q01": "q01_chart",
    "q04": "q04_chart",
    "q07": "q07_chart",
    "q09": "q09_chart",
    "q13": "q13_chart",
    "q15": "q15_chart",
}

CHINESE_RE = re.compile(r"[\u3400-\u9fff]")


def lit(value: str) -> dict[str, Any]:
    return {"expr": {"Literal": {"Value": value}}}


def solid(hex_color: str) -> dict[str, Any]:
    return {
        "solid": {
            "color": {
                "expr": {
                    "Literal": {
                        "Value": f"'{hex_color}'"
                    }
                }
            }
        }
    }


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def measure_block(name: str, expression: str, fmt: str) -> str:
    lineage = uuid.uuid5(uuid.NAMESPACE_URL, f"bism2202-kpi:{name}")
    return (
        f"\tmeasure '{name}' = {expression}\n"
        f"\t\tformatString: {fmt}\n"
        f"\t\tdisplayFolder: BISM2202 Dashboard KPIs\n"
        f"\t\tlineageTag: {lineage}\n\n"
    )


def ensure_kpi_measures(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    missing = [(n, e, f) for n, e, f in KPI_MEASURES if f"measure '{n}'" not in text]
    if not missing:
        return
    marker = "\tcolumn 'Order ID'"
    idx = text.find(marker)
    if idx < 0:
        raise RuntimeError(f"{path}: could not find insertion point before Order ID column")
    blocks = "".join(measure_block(*item) for item in missing)
    text = text[:idx] + blocks + text[idx:]
    path.write_text(text, encoding="utf-8")


def card_visual(name: str, title: str, measure: str, x: float, color: str, tab_order: int) -> dict[str, Any]:
    return {
        "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.12.0/schema.json",
        "name": name,
        "position": {
            "x": x,
            "y": 32,
            "z": 20 + tab_order,
            "height": 108,
            "width": 370,
            "tabOrder": tab_order,
        },
        "visual": {
            "visualType": "card",
            "query": {
                "queryState": {
                    "Values": {
                        "projections": [
                            {
                                "field": {
                                    "Measure": {
                                        "Expression": {"SourceRef": {"Entity": "PizzaOrders"}},
                                        "Property": measure,
                                    }
                                },
                                "queryRef": f"PizzaOrders.{measure}",
                                "nativeQueryRef": measure,
                            }
                        ]
                    }
                }
            },
            "objects": {
                "labels": [
                    {
                        "properties": {
                            "fontSize": lit("24D"),
                            "labelDisplayUnits": lit("0D"),
                        }
                    }
                ]
            },
            "visualContainerObjects": {
                "title": [
                    {
                        "properties": {
                            "show": lit("true"),
                            "text": lit(f"'{title}'"),
                            "fontSize": lit("11D"),
                            "fontColor": solid("#4B5563"),
                        }
                    }
                ],
                "background": [
                    {
                        "properties": {
                            "color": solid("#FFFFFF"),
                            "transparency": lit("0D"),
                        }
                    }
                ],
                "border": [
                    {
                        "properties": {
                            "show": lit("true"),
                            "color": solid(color),
                        }
                    }
                ],
            },
            "drillFilterOtherVisuals": True,
        },
        "filterConfig": {
            "filters": [
                {
                    "name": f"kpi_{name}_filter",
                    "field": {
                        "Measure": {
                            "Expression": {"SourceRef": {"Entity": "PizzaOrders"}},
                            "Property": measure,
                        }
                    },
                    "type": "Advanced",
                }
            ]
        },
    }


def set_page_background(page_json: Path) -> None:
    data = load_json(page_json)
    data.setdefault("objects", {})["background"] = [
        {
            "properties": {
                "color": solid("#F7F9FC"),
                "transparency": lit("0D"),
            }
        }
    ]
    save_json(page_json, data)


def patch_page(report_root: Path, version: str, page: str) -> None:
    page_root = report_root / "definition" / "pages" / page
    visuals_root = page_root / "visuals"
    main_name = MAIN_VISUALS[page]
    main_path = visuals_root / main_name / "visual.json"
    if not main_path.exists():
        raise FileNotFoundError(main_path)

    main = load_json(main_path)
    pos = main.setdefault("position", {})
    pos.update({"x": 35, "y": 162, "z": 0, "height": 505, "width": 1210, "tabOrder": 10})
    save_json(main_path, main)
    set_page_background(page_root / "page.json")

    for child in visuals_root.iterdir():
        if child.is_dir() and child.name.startswith("kpi_"):
            shutil.rmtree(child)

    xs = [35, 455, 875]
    colors = PALETTES[version]
    for idx, ((title, measure), x, color) in enumerate(zip(PAGE_CARDS[page], xs, colors), start=1):
        name = f"kpi_{page}_{idx}"
        save_json(visuals_root / name / "visual.json", card_visual(name, title, measure, x, color, idx))


def validate_version(version: str) -> None:
    report_root = REPORT_ROOTS[version]
    table_path = MODEL_TABLES[version]
    tmdl = table_path.read_text(encoding="utf-8")
    for name, _, _ in KPI_MEASURES:
        if tmdl.count(f"measure '{name}'") != 1:
            raise RuntimeError(f"Version {version}: KPI measure {name!r} missing or duplicated")

    for page in PAGE_CARDS:
        visuals_root = report_root / "definition" / "pages" / page / "visuals"
        cards = sorted(p for p in visuals_root.iterdir() if p.is_dir() and p.name.startswith(f"kpi_{page}_"))
        if len(cards) != 3:
            raise RuntimeError(f"Version {version} {page}: expected 3 KPI cards, found {len(cards)}")
        main = load_json(visuals_root / MAIN_VISUALS[page] / "visual.json")
        pos = main.get("position", {})
        if pos.get("y") != 162 or pos.get("height") != 505:
            raise RuntimeError(f"Version {version} {page}: main visual layout validation failed")
        for card in cards:
            data = load_json(card / "visual.json")
            if data.get("visual", {}).get("visualType") != "card":
                raise RuntimeError(f"Version {version} {page}: {card.name} is not a card visual")

    offenders: list[str] = []
    for path in report_root.glob("definition/pages/*/visuals/*/visual.json"):
        if CHINESE_RE.search(path.read_text(encoding="utf-8")):
            offenders.append(str(path.relative_to(report_root)))
    if offenders:
        raise RuntimeError("Explicit Chinese text remains in visual definitions: " + ", ".join(offenders))


def patch_version(version: str) -> None:
    report_root = REPORT_ROOTS[version]
    table_path = MODEL_TABLES[version]
    if not report_root.exists() or not table_path.exists():
        raise FileNotFoundError(f"Version {version} source project is incomplete")

    ensure_kpi_measures(table_path)
    for page in PAGE_CARDS:
        patch_page(report_root, version, page)
    validate_version(version)

    print(f"Version {version}: semantic-model KPI measures PASS")
    print(f"Version {version}: Q01/Q04/Q07/Q09/Q13/Q15 mini dashboards PASS")
    print(f"Version {version}: 18 KPI cards created PASS")
    print(f"Version {version}: explicit-Chinese visual-definition scan PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", choices=["A", "B", "Both"], default="Both")
    args = parser.parse_args()
    versions = ["A", "B"] if args.version == "Both" else [args.version]
    for version in versions:
        patch_version(version)
    print("MINI_DASHBOARD_UPGRADE: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
