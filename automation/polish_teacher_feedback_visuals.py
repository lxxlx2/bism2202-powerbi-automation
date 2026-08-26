#!/usr/bin/env python3
"""Upgrade BISM2202 Power BI visuals while preserving question logic.

This script edits PBIR formatting/query presentation for both source projects.
It does not save/export PBIX. Power BI must be closed while it runs.

Design goals:
- preserve every question's requested metric and calculation;
- improve information density with labels, sorting, concise subtitles and Top-N;
- use semantic, consistent color encodings;
- keep A/B visually distinct;
- avoid clutter on long time series;
- prevent explicit Chinese text in submission visual definitions.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
REPORT_ROOTS = {
    "A": ROOT / "PROJECT" / "Version_A_PowerBI" / "BISM2202_Seed.Report",
    "B": ROOT / "PROJECT" / "Version_B_PowerBI" / "BISM2202_Seed.Report",
}

PALETTES = {
    "A": {
        "blue": "#2F80ED",
        "navy": "#2D3A8C",
        "teal": "#27AE60",
        "cyan": "#56CCF2",
        "orange": "#F2994A",
        "red": "#D64550",
        "purple": "#9B51E0",
        "gold": "#E6B422",
        "gray": "#A7B0BE",
        "darkgray": "#5B6573",
    },
    "B": {
        "blue": "#457B9D",
        "navy": "#4F5BD5",
        "teal": "#2A9D8F",
        "cyan": "#66C2C9",
        "orange": "#E76F51",
        "red": "#C94C4C",
        "purple": "#7B61A8",
        "gold": "#E0A82E",
        "gray": "#A6ADB8",
        "darkgray": "#59616D",
    },
}

CHINESE_RE = re.compile(r"[\u3400-\u9fff]")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, data: dict[str, Any]) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def literal(value: str) -> dict[str, Any]:
    return {"expr": {"Literal": {"Value": value}}}


def color_expr(hex_color: str) -> dict[str, Any]:
    return {
        "fill": {
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
    }


def measure_field(entity: str, prop: str) -> dict[str, Any]:
    return {
        "Measure": {
            "Expression": {"SourceRef": {"Entity": entity}},
            "Property": prop,
        }
    }


def category_identity(data: dict[str, Any]) -> tuple[str, str]:
    projections = (
        data.get("visual", {})
        .get("query", {})
        .get("queryState", {})
        .get("Category", {})
        .get("projections", [])
    )
    if not projections:
        raise ValueError("visual has no Category projection")
    column = projections[0].get("field", {}).get("Column")
    if column is None:
        raise ValueError("Category projection is not a Column")
    entity = column.get("Expression", {}).get("SourceRef", {}).get("Entity")
    prop = column.get("Property")
    if not entity or not prop:
        raise ValueError("cannot determine Category entity/property")
    return str(entity), str(prop)


def category_selector(entity: str, prop: str, value: str) -> dict[str, Any]:
    escaped = value.replace("'", "''")
    return {
        "data": [
            {
                "scopeId": {
                    "Comparison": {
                        "ComparisonKind": 0,
                        "Left": {
                            "Column": {
                                "Expression": {"SourceRef": {"Entity": entity}},
                                "Property": prop,
                            }
                        },
                        "Right": {"Literal": {"Value": f"'{escaped}'"}},
                    }
                }
            }
        ]
    }


def find_visual(report_root: Path, page: str, visual_name: str) -> Path:
    path = report_root / "definition" / "pages" / page / "visuals" / visual_name / "visual.json"
    if not path.exists():
        raise FileNotFoundError(path)
    return path


def visual_path(report_root: Path, page: str, name: str | None = None) -> Path:
    if name:
        return find_visual(report_root, page, name)
    candidates = list((report_root / "definition" / "pages" / page / "visuals").glob("*/visual.json"))
    if len(candidates) != 1:
        raise ValueError(f"{page}: expected one visual, found {len(candidates)}")
    return candidates[0]


def apply_default_color(path: Path, hex_color: str) -> None:
    data = load_json(path)
    visual = data.setdefault("visual", {})
    visual.setdefault("objects", {})["dataPoint"] = [{"properties": color_expr(hex_color)}]
    save_json(path, data)


def apply_category_colors(path: Path, category_colors: dict[str, str], default_color: str | None = None) -> None:
    data = load_json(path)
    entity, prop = category_identity(data)
    points: list[dict[str, Any]] = []
    points.append({"properties": color_expr(default_color)} if default_color else {"properties": {}})
    for category, color in category_colors.items():
        points.append(
            {
                "properties": color_expr(color),
                "selector": category_selector(entity, prop, category),
            }
        )
    data.setdefault("visual", {}).setdefault("objects", {})["dataPoint"] = points
    save_json(path, data)


def set_labels(path: Path, *, show: bool = True, precision: int = 0, display_units: int = 0) -> None:
    data = load_json(path)
    objects = data.setdefault("visual", {}).setdefault("objects", {})
    objects["labels"] = [
        {
            "properties": {
                "show": literal("true" if show else "false"),
                "labelDisplayUnits": literal(f"{display_units}D"),
                "labelPrecision": literal(f"{precision}D"),
            }
        }
    ]
    save_json(path, data)


def set_title_subtitle(path: Path, title: str, subtitle: str | None = None) -> None:
    data = load_json(path)
    visual = data.setdefault("visual", {})
    container = visual.setdefault("visualContainerObjects", {})
    container["title"] = [{"properties": {"text": literal(f"'{title}'")}}]
    if subtitle:
        container["subTitle"] = [
            {
                "properties": {
                    "show": literal("true"),
                    "text": literal(f"'{subtitle}'"),
                }
            }
        ]
    else:
        container["subTitle"] = [{"properties": {"show": literal("false")}}]
    save_json(path, data)


def set_sort_measure(path: Path, measure: str, direction: str = "Descending") -> None:
    data = load_json(path)
    query = data.setdefault("visual", {}).setdefault("query", {})
    query["sortDefinition"] = {
        "sort": [
            {
                "field": measure_field("PizzaOrders", measure),
                "direction": direction,
            }
        ],
        "isDefaultSort": True,
    }
    save_json(path, data)


def set_top_n(path: Path, n: int) -> None:
    data = load_json(path)
    changed = False
    for item in data.get("filterConfig", {}).get("filters", []):
        if item.get("type") != "TopN":
            continue
        try:
            query = item["filter"]["From"][0]["Expression"]["Subquery"]["Query"]
            query["Top"] = n
            changed = True
        except (KeyError, IndexError, TypeError):
            continue
    if not changed:
        raise ValueError(f"{path}: expected existing TopN filter")
    save_json(path, data)


def polish_version(version: str) -> None:
    root = REPORT_ROOTS[version]
    p = PALETTES[version]
    if not root.exists():
        raise FileNotFoundError(root)

    # Q01: ranking chart. Keep Top 20, show exact order counts and highlight top 3.
    q01 = visual_path(root, "q01", "q01_chart")
    apply_category_colors(q01, {
        "Atlanta, GA": p["orange"],
        "Milwaukee, WI": p["teal"],
        "Louisville, KY": p["purple"],
    }, default_color=p["blue"])
    set_labels(q01, precision=0)
    set_sort_measure(q01, "Order Count", "Descending")
    set_title_subtitle(q01, "Top 20 Locations by Order Count", "Exact counts shown • Top 3 locations highlighted")

    pizza_colors = {"Large": p["blue"], "Medium": p["teal"], "Small": p["orange"], "XL": p["purple"]}

    # Q02: direct category comparison with exact average minutes.
    q02 = visual_path(root, "q02", "q02_chart")
    apply_category_colors(q02, pizza_colors)
    set_labels(q02, precision=2)
    set_sort_measure(q02, "Avg Delivery Duration", "Descending")
    set_title_subtitle(q02, "Average Delivery Duration by Pizza Size", "Average minutes • sorted longest to shortest")

    # Q03: share view, sorted so the composition is immediately readable.
    q03 = visual_path(root, "q03", "q03_chart")
    apply_category_colors(q03, pizza_colors)
    set_labels(q03, precision=2)
    set_sort_measure(q03, "Order Share Overall", "Descending")
    set_title_subtitle(q03, "Share of Orders by Pizza Size", "Percentage of all orders • sorted by share")

    # Q04: payment volume with exact counts and ranking.
    q04 = visual_path(root, "q04", "q04_chart")
    apply_category_colors(q04, {
        "Card": p["blue"], "Cash": p["teal"], "Domino's Cash": p["orange"],
        "Hut Points": p["purple"], "UPI": p["gold"], "Wallet": p["cyan"],
    })
    set_labels(q04, precision=0)
    set_sort_measure(q04, "Order Count", "Descending")
    set_title_subtitle(q04, "Orders by Payment Method", "Order count • sorted most to least used")

    traffic_colors = {"High": p["red"], "Medium": p["gold"], "Low": p["teal"]}

    # Q05: semantic traffic colors plus exact percentages.
    q05 = visual_path(root, "q05", "q05_chart")
    apply_category_colors(q05, traffic_colors)
    set_labels(q05, precision=2)
    set_sort_measure(q05, "Order Share Overall", "Descending")
    set_title_subtitle(q05, "Share of Orders by Traffic Level", "Percentage of all orders • semantic traffic colors")

    # Q06: binary comparison with exact averages.
    q06 = visual_path(root, "q06", "q06_chart")
    apply_category_colors(q06, {"Weekday": p["blue"], "Weekend": p["purple"]})
    set_labels(q06, precision=2)
    set_title_subtitle(q06, "Average Toppings: Weekday vs Weekend", "Average toppings per order")

    # Q07: correct the visual hierarchy. Top 10 only, exact averages, same color for tied leaders.
    q07 = visual_path(root, "q07", "q07_chart")
    apply_category_colors(q07, {
        "Fort Wayne, IN": p["red"],
        "Newark, NJ": p["red"],
    }, default_color=p["blue"])
    set_top_n(q07, 10)
    set_labels(q07, precision=2)
    set_sort_measure(q07, "Avg Delivery Duration", "Descending")
    set_title_subtitle(q07, "Top 10 Locations by Average Delivery Duration", "Average minutes • tied leaders use the same highlight")

    # Q08: contrast peak and non-peak, show counts.
    q08 = visual_path(root, "q08", "q08_chart")
    apply_category_colors(q08, {"Peak Hour": p["navy"], "Non-Peak Hour": p["cyan"]})
    set_labels(q08, precision=0)
    set_sort_measure(q08, "Order Count", "Descending")
    set_title_subtitle(q08, "Orders During Peak vs Non-Peak Hours", "Exact order counts • direct demand comparison")

    # Q09: corrected English Month-Year chronology; avoid 31 overlapping labels.
    q09 = visual_path(root, "q09", "q09_chart")
    apply_default_color(q09, p["blue"] if version == "A" else p["teal"])
    set_labels(q09, show=False)
    set_title_subtitle(q09, "Order Volume Trend by Month-Year", "31 chronological monthly points • Jan 2024 to Jul 2026")

    # Q10: pizza-size average toppings, ranked and labeled.
    q10 = visual_path(root, "q10", "q10_chart")
    apply_category_colors(q10, pizza_colors)
    set_labels(q10, precision=2)
    set_sort_measure(q10, "Avg Toppings Count", "Descending")
    set_title_subtitle(q10, "Average Toppings Count by Pizza Size", "Average toppings • sorted highest to lowest")

    # Q11: exactly the requested two fastest / most reliable performers.
    q11 = visual_path(root, "q11", "q11_chart")
    apply_category_colors(q11, {"Little Caesars": p["teal"], "Domino's": p["cyan"]}, default_color=p["gray"])
    set_labels(q11, precision=2)
    set_sort_measure(q11, "Avg Delay", "Ascending")
    set_title_subtitle(q11, "Two Restaurants with Lowest Average Delay", "Average delay minutes • lower is better")

    # Q12: Top 5 pizza types with exact averages.
    q12 = visual_path(root, "q12", "q12_chart")
    apply_category_colors(q12, {
        "Stuffed Crust": p["orange"], "Gluten-Free": p["blue"], "Cheese Burst": p["teal"],
        "Thai Chicken": p["purple"], "Sicilian": p["gold"],
    })
    set_labels(q12, precision=2)
    set_sort_measure(q12, "Avg Delivery Duration", "Descending")
    set_title_subtitle(q12, "Top 5 Pizza Types by Average Delivery Duration", "Average minutes • ranked highest to lowest")

    # Q13: hourly pattern with exact counts. Single accent keeps time order clear.
    q13 = visual_path(root, "q13", "q13_chart")
    apply_default_color(q13, p["orange"] if version == "A" else p["navy"])
    set_labels(q13, precision=0)
    set_title_subtitle(q13, "Order Volume by Order Hour", "Exact counts reveal the 18:00 to 20:00 demand peak")

    # Q14: semantic traffic colors and exact average delay values.
    q14 = visual_path(root, "q14", "q14_chart")
    apply_category_colors(q14, traffic_colors)
    set_labels(q14, precision=2)
    set_sort_measure(q14, "Avg Delay", "Descending")
    set_title_subtitle(q14, "Average Delay by Traffic Level", "Average minutes • heavier traffic is visually emphasized")

    # Q15: fix the visually confusing numeric-category order by ranking by share.
    q15 = visual_path(root, "q15", "q15_chart")
    apply_default_color(q15, p["purple"] if version == "A" else p["orange"])
    set_labels(q15, precision=2)
    set_sort_measure(q15, "Order Share Overall", "Descending")
    set_title_subtitle(q15, "Order Share by Pizza Complexity", "Percentage labels • categories ranked by share")

    # Q16/Q19 already use conditional formatting. Q17/Q18 are intentionally multi-visual.
    # Q20 is already a three-visual dashboard. Preserve those richer assignment-specific designs.

    offenders: list[str] = []
    for path in (root / "definition" / "pages").glob("**/visual.json"):
        text = path.read_text(encoding="utf-8")
        if CHINESE_RE.search(text):
            offenders.append(str(path.relative_to(root)))
    if offenders:
        raise RuntimeError(f"Version {version}: explicit Chinese remains in visual JSON: {offenders}")

    print(f"Version {version}: richer information design applied without changing assignment calculations.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", choices=["A", "B", "Both"], default="Both")
    args = parser.parse_args()
    versions = ["A", "B"] if args.version == "Both" else [args.version]
    for version in versions:
        polish_version(version)
    print("TEACHER_FEEDBACK_VISUAL_POLISH_SOURCE: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
