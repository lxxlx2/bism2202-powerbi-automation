#!/usr/bin/env python3
"""Final deterministic cleanup for the teacher-feedback visual pass.

Runs after polish_teacher_feedback_visuals.py.
It only corrects presentation issues discovered during live visual review:
- Q07: Top-N can legitimately return more than 10 rows when the cutoff is tied,
  so the title/subtitle must describe the actual behavior instead of claiming
  exactly 10 rows.
- Q15: Pizza Complexity is an ordered numeric scale. Keep the scale in a stable
  high-to-low order and describe the chart accurately instead of claiming it is
  ranked by share.

No measures, bindings, calculations, or source data are changed.
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
CHINESE_RE = re.compile(r"[\u3400-\u9fff]")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, data: dict[str, Any]) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def literal(value: str) -> dict[str, Any]:
    return {"expr": {"Literal": {"Value": value}}}


def visual_path(root: Path, page: str, name: str) -> Path:
    path = root / "definition" / "pages" / page / "visuals" / name / "visual.json"
    if not path.exists():
        raise FileNotFoundError(path)
    return path


def set_title_subtitle(path: Path, title: str, subtitle: str) -> None:
    data = load_json(path)
    visual = data.setdefault("visual", {})
    container = visual.setdefault("visualContainerObjects", {})
    container["title"] = [{"properties": {"text": literal(f"'{title}'")}}]
    container["subTitle"] = [{
        "properties": {
            "show": literal("true"),
            "text": literal(f"'{subtitle}'"),
        }
    }]
    save_json(path, data)


def set_sort_column(path: Path, entity: str, prop: str, direction: str) -> None:
    data = load_json(path)
    query = data.setdefault("visual", {}).setdefault("query", {})
    query["sortDefinition"] = {
        "sort": [{
            "field": {
                "Column": {
                    "Expression": {"SourceRef": {"Entity": entity}},
                    "Property": prop,
                }
            },
            "direction": direction,
        }],
        "isDefaultSort": True,
    }
    save_json(path, data)


def top_n_value(path: Path) -> int | None:
    data = load_json(path)
    for item in data.get("filterConfig", {}).get("filters", []):
        if item.get("type") != "TopN":
            continue
        try:
            return int(item["filter"]["From"][0]["Expression"]["Subquery"]["Query"]["Top"])
        except (KeyError, IndexError, TypeError, ValueError):
            return None
    return None


def assert_no_explicit_chinese(root: Path) -> None:
    offenders: list[str] = []
    for path in root.glob("definition/pages/*/visuals/*/visual.json"):
        text = path.read_text(encoding="utf-8")
        if CHINESE_RE.search(text):
            offenders.append(str(path.relative_to(root)))
    if offenders:
        raise RuntimeError("Explicit Chinese text remains in visual definitions: " + ", ".join(offenders))


def validate_q15(path: Path) -> None:
    data = load_json(path)
    sort_items = data.get("visual", {}).get("query", {}).get("sortDefinition", {}).get("sort", [])
    if len(sort_items) != 1:
        raise RuntimeError(f"{path}: expected one deterministic Q15 sort")
    field = sort_items[0].get("field", {}).get("Column", {})
    if field.get("Property") != "Pizza Complexity":
        raise RuntimeError(f"{path}: Q15 is not sorted by Pizza Complexity")
    if sort_items[0].get("direction") != "Descending":
        raise RuntimeError(f"{path}: Q15 sort is not Descending")


def patch_version(version: str) -> None:
    root = REPORT_ROOTS[version]
    if not root.exists():
        raise FileNotFoundError(root)

    q07 = visual_path(root, "q07", "q07_chart")
    n = top_n_value(q07)
    if n != 10:
        raise RuntimeError(f"Version {version}: Q07 expected TopN=10, found {n}")
    set_title_subtitle(
        q07,
        "Locations with Highest Average Delivery Duration",
        "Average minutes • Top-N cutoff retains all tied locations",
    )

    q15 = visual_path(root, "q15", "q15_chart")
    set_sort_column(q15, "PizzaOrders", "Pizza Complexity", "Descending")
    set_title_subtitle(
        q15,
        "Order Share by Pizza Complexity",
        "Percentage of all orders • complexity scale shown high to low",
    )
    validate_q15(q15)

    assert_no_explicit_chinese(root)
    print(f"Version {version}: Q07 tie-safe labeling PASS")
    print(f"Version {version}: Q15 deterministic complexity ordering PASS")
    print(f"Version {version}: explicit-Chinese visual-definition scan PASS")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", choices=["A", "B", "Both"], default="Both")
    args = parser.parse_args()
    versions = ["A", "B"] if args.version == "Both" else [args.version]
    for version in versions:
        patch_version(version)
    print("REMAINING_VISUAL_ISSUES_FIX: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
