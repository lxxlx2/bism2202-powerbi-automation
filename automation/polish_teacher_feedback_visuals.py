#!/usr/bin/env python3
"""Polish BISM2202 Power BI visuals without changing measures or question logic.

This script only edits PBIR visual formatting in the two source projects. It is
safe to run repeatedly. Power BI must be closed while it runs. Saving the PBIP
and exporting/replacing the final PBIX remain manual steps in Power BI.
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

# Version A uses a blue/teal/orange academic palette. Version B uses a
# teal/indigo/coral palette so the two submissions remain visually distinct.
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
    },
}

CHINESE_RE = re.compile(r"[\u3400-\u9fff]")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, data: dict[str, Any]) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


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

    field = projections[0].get("field", {})
    column = field.get("Column")
    if column is None:
        raise ValueError("Category projection is not a Column")

    source_ref = column.get("Expression", {}).get("SourceRef", {})
    entity = source_ref.get("Entity")
    prop = column.get("Property")
    if not entity or not prop:
        raise ValueError("cannot determine Category entity/property")
    return str(entity), str(prop)


def category_selector(entity: str, prop: str, value: str) -> dict[str, Any]:
    return {
        "data": [
            {
                "scopeId": {
                    "Comparison": {
                        "ComparisonKind": 0,
                        "Left": {
                            "Column": {
                                "Expression": {
                                    "SourceRef": {
                                        "Entity": entity
                                    }
                                },
                                "Property": prop,
                            }
                        },
                        "Right": {
                            "Literal": {
                                "Value": f"'{value.replace(chr(39), chr(39) * 2)}'"
                            }
                        },
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


def apply_default_color(path: Path, hex_color: str) -> None:
    data = load_json(path)
    visual = data.setdefault("visual", {})
    objects = visual.setdefault("objects", {})
    objects["dataPoint"] = [{"properties": color_expr(hex_color)}]
    save_json(path, data)


def apply_category_colors(
    path: Path,
    category_colors: dict[str, str],
    default_color: str | None = None,
) -> None:
    data = load_json(path)
    entity, prop = category_identity(data)

    points: list[dict[str, Any]] = []
    if default_color:
        points.append({"properties": color_expr(default_color)})
    else:
        # Keeping the empty default item matches Power BI's own PBIR output.
        points.append({"properties": {}})

    for category, color in category_colors.items():
        points.append(
            {
                "properties": color_expr(color),
                "selector": category_selector(entity, prop, category),
            }
        )

    visual = data.setdefault("visual", {})
    objects = visual.setdefault("objects", {})
    objects["dataPoint"] = points
    save_json(path, data)


def visual_path(report_root: Path, page: str, name: str | None = None) -> Path:
    if name:
        return find_visual(report_root, page, name)
    candidates = list((report_root / "definition" / "pages" / page / "visuals").glob("*/visual.json"))
    if len(candidates) != 1:
        raise ValueError(f"{page}: expected one visual, found {len(candidates)}")
    return candidates[0]


def polish_version(version: str) -> None:
    root = REPORT_ROOTS[version]
    p = PALETTES[version]

    if not root.exists():
        raise FileNotFoundError(root)

    # Q01/Q07 remain restrained ranking charts. Highlight only the leaders so
    # twenty/top-ten categories do not become visually noisy.
    apply_category_colors(
        visual_path(root, "q01", "q01_chart"),
        {
            "Atlanta, GA": p["orange"],
            "Milwaukee, WI": p["teal"],
            "Louisville, KY": p["purple"],
        },
        default_color=p["blue"],
    )

    # Pizza-size questions use the same semantic palette within each version.
    pizza_colors = {
        "Large": p["blue"],
        "Medium": p["teal"],
        "Small": p["orange"],
        "XL": p["purple"],
    }
    apply_category_colors(visual_path(root, "q02", "q02_chart"), pizza_colors)
    apply_category_colors(visual_path(root, "q03", "q03_chart"), pizza_colors)
    apply_category_colors(visual_path(root, "q10", "q10_chart"), pizza_colors)

    # Payment methods benefit from categorical color separation.
    apply_category_colors(
        visual_path(root, "q04", "q04_chart"),
        {
            "Card": p["blue"],
            "Cash": p["teal"],
            "Domino's Cash": p["orange"],
            "Hut Points": p["purple"],
            "UPI": p["gold"],
            "Wallet": p["cyan"],
        },
    )

    # Traffic colors are deliberately semantic and consistent wherever traffic
    # level appears: high = red, medium = amber, low = green/teal.
    traffic_colors = {
        "High": p["red"],
        "Medium": p["gold"],
        "Low": p["teal"],
    }
    apply_category_colors(visual_path(root, "q05", "q05_chart"), traffic_colors)
    apply_category_colors(visual_path(root, "q14", "q14_chart"), traffic_colors)

    # Binary comparisons use deliberately contrasting colors.
    apply_category_colors(
        visual_path(root, "q06", "q06_chart"),
        {
            "Weekday": p["blue"],
            "Weekend": p["purple"],
        },
    )
    apply_category_colors(
        visual_path(root, "q08", "q08_chart"),
        {
            "Peak Hour": p["navy"],
            "Non-Peak Hour": p["cyan"],
        },
    )

    # Q07 highlights the tied longest-duration leaders while retaining a clean
    # default color for the rest of the top-ten locations.
    apply_category_colors(
        visual_path(root, "q07", "q07_chart"),
        {
            "Fort Wayne, IN": p["orange"],
            "Newark, NJ": p["red"],
        },
        default_color=p["blue"],
    )

    # Keep the corrected Q09 chronology and give each version its own accent.
    apply_default_color(visual_path(root, "q09", "q09_chart"), p["blue"] if version == "A" else p["teal"])

    # Q11 visually emphasizes the two requested best performers.
    apply_category_colors(
        visual_path(root, "q11", "q11_chart"),
        {
            "Little Caesars": p["teal"],
            "Domino's": p["cyan"],
        },
        default_color=p["gray"],
    )

    # Q12 retains a ranking-friendly bar/column layout while differentiating
    # the five requested pizza types.
    apply_category_colors(
        visual_path(root, "q12", "q12_chart"),
        {
            "Stuffed Crust": p["orange"],
            "Gluten-Free": p["blue"],
            "Cheese Burst": p["teal"],
            "Thai Chicken": p["purple"],
            "Sicilian": p["gold"],
        },
    )

    # Q13 is a time-series chart, so a single strong accent is clearer than
    # rainbow coloring. Q15 remains multi-category but gets a distinct accent.
    apply_default_color(visual_path(root, "q13", "q13_chart"), p["orange"] if version == "A" else p["navy"])
    apply_default_color(visual_path(root, "q15", "q15_chart"), p["purple"] if version == "A" else p["orange"])

    # Q16/Q19 already use conditional formatting; Q17/Q18 are multi-series;
    # Q20 is already a three-visual dashboard. Their existing richer encodings
    # are preserved to avoid weakening the assignment-specific design.

    # Defensive check: no explicit Chinese text is allowed in submission visual
    # definitions. Rendered screenshots will still be visually reviewed later.
    offenders: list[str] = []
    for path in (root / "definition" / "pages").glob("**/visual.json"):
        text = path.read_text(encoding="utf-8")
        if CHINESE_RE.search(text):
            offenders.append(str(path.relative_to(root)))
    if offenders:
        raise RuntimeError(f"Version {version}: explicit Chinese remains in visual JSON: {offenders}")

    print(f"Version {version}: polished visual palette applied without changing bindings/measures.")


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
