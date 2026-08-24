#!/usr/bin/env python3
"""Audit the saved PBIX package against the BISM2202 final requirements."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path

from automation_common import log_path, project_root


def _read_json(archive: zipfile.ZipFile, name: str) -> dict:
    return json.loads(archive.read(name).decode("utf-8-sig"))


def _visual(archive: zipfile.ZipFile, page: str, name: str) -> dict:
    return _read_json(archive, f"Report/definition/pages/{page}/visuals/{name}/visual.json")["visual"]


def _projection_properties(visual: dict) -> set[str]:
    properties: set[str] = set()
    for role in visual.get("query", {}).get("queryState", {}).values():
        for projection in role.get("projections", []):
            field = projection.get("field", {})
            for kind in ("Column", "Measure"):
                prop = field.get(kind, {}).get("Property")
                if prop:
                    properties.add(prop)
    return properties


def _sorts_by(visual: dict, property_name: str, direction: str = "Ascending") -> bool:
    sorts = visual.get("query", {}).get("sortDefinition", {}).get("sort", [])
    for item in sorts:
        field = item.get("field", {})
        prop = field.get("Column", {}).get("Property") or field.get("Measure", {}).get("Property")
        if prop == property_name and item.get("direction") == direction:
            return True
    return False


def _literal_values(value: object) -> list[str]:
    found: list[str] = []
    if isinstance(value, dict):
        literal = value.get("Literal")
        if isinstance(literal, dict) and isinstance(literal.get("Value"), str):
            found.append(literal["Value"])
        for child in value.values():
            found.extend(_literal_values(child))
    elif isinstance(value, list):
        for child in value:
            found.extend(_literal_values(child))
    return found


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", choices=["A", "B"], required=True)
    parser.add_argument("--pbix", type=Path)
    args = parser.parse_args()

    output = project_root() / f"Version_{args.version}"
    pbix = args.pbix or output / f"BISM2202_Assignment_{args.version}.pbix"
    issues: list[str] = []
    checks: dict[str, object] = {}

    if not pbix.is_file():
        issues.append(f"Missing PBIX: {pbix}")
    else:
        try:
            with zipfile.ZipFile(pbix) as archive:
                corrupt = archive.testzip()
                if corrupt:
                    issues.append(f"Corrupt PBIX entry: {corrupt}")
                names = set(archive.namelist())
                for required in ("DataModel", "Report/definition/pages/pages.json", "Report/definition/report.json"):
                    if required not in names:
                        issues.append(f"Missing PBIX entry: {required}")

                pages = _read_json(archive, "Report/definition/pages/pages.json")
                page_order = pages.get("pageOrder", [])
                checks["page_order"] = page_order
                if page_order != [f"q{number:02d}" for number in range(1, 21)]:
                    issues.append("PBIX does not contain q01-q20 in order.")

                q09 = _visual(archive, "q09", "q09_chart")
                if "Order Month Start" not in _projection_properties(q09):
                    issues.append("Q09 does not use the real date field Order Month Start.")
                if {"Order Month English", "Order Month Sorted", "Order Month-Year"} & _projection_properties(q09):
                    issues.append("Q09 still uses the old month-only field.")
                if not _sorts_by(q09, "Order Month Start"):
                    issues.append("Q09 is not explicitly sorted by Order Month Start ascending.")

                for page, visual_name in (
                    ("q13", "q13_chart"),
                    ("q17", "q17_volume"),
                    ("q17", "q17_delay"),
                    ("q20", "q20_hourly_line"),
                ):
                    if not _sorts_by(_visual(archive, page, visual_name), "Order Hour"):
                        issues.append(f"{page.upper()} {visual_name} is not sorted by Order Hour ascending.")

                q16 = _visual(archive, "q16", "q16_matrix")
                q16_props = _projection_properties(q16)
                if not {"Restaurant Name", "Avg Delivery Duration", "Avg Delay"}.issubset(q16_props):
                    issues.append("Q16 matrix fields are incomplete.")
                conditional = json.dumps(q16.get("objects", {}).get("values", []), ensure_ascii=False)
                for measure in ("Delivery Duration Color", "Delay Color"):
                    if measure not in conditional:
                        issues.append(f"Q16 conditional formatting is missing {measure}.")
                if "'Total'" not in _literal_values(q16.get("objects", {})):
                    issues.append("Q16 does not contain the explicit English Total label.")

                q19 = _visual(archive, "q19", "q19_stack")
                if not {"Payment Method", "Traffic Level", "Order Share Within Payment"}.issubset(_projection_properties(q19)):
                    issues.append("Q19 within-payment percentage matrix fields are incomplete.")
                q19_slicer = _visual(archive, "q19", "q19_time_slicer")
                if "Order Time" not in _projection_properties(q19_slicer):
                    issues.append("Q19 Order Time slicer is missing.")
                if "'Total'" not in _literal_values(q19.get("objects", {})):
                    issues.append("Q19 does not contain the explicit English Total label.")

                q20_prefix = "Report/definition/pages/q20/visuals/"
                q20_visuals = sorted({name.split("/")[5] for name in names if name.startswith(q20_prefix) and name.endswith("/visual.json")})
                checks["q20_visuals"] = q20_visuals
                if q20_visuals != ["q20_hourly_line", "q20_restaurant", "q20_traffic"]:
                    issues.append(f"Q20 must contain exactly three required visuals; found {q20_visuals}.")

                report_text = "\n".join(
                    archive.read(name).decode("utf-8-sig", errors="replace")
                    for name in names
                    if name.startswith("Report/definition/") and name.endswith(".json")
                )
                cjk = re.findall(r"[\u3400-\u9fff]", report_text)
                checks["report_definition_cjk_count"] = len(cjk)
                if cjk:
                    issues.append(f"Report definition contains {len(cjk)} CJK characters that may leak onto the canvas.")
        except (zipfile.BadZipFile, KeyError, json.JSONDecodeError) as exc:
            issues.append(f"PBIX package could not be audited: {exc}")

    result = {
        "status": "PASS" if not issues else "FAIL",
        "version": args.version,
        "pbix": str(pbix),
        "bytes": pbix.stat().st_size if pbix.is_file() else 0,
        "sha256": hashlib.sha256(pbix.read_bytes()).hexdigest() if pbix.is_file() else None,
        "checks": checks,
        "issues": issues,
    }
    report = log_path(f"validate_pbix_structure_{args.version}").with_suffix(".json")
    report.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if not issues else 2


if __name__ == "__main__":
    raise SystemExit(main())
