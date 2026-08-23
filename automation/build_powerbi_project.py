#!/usr/bin/env python3
"""Prepare validated inputs and output folders for a genuine Power BI project.

This script deliberately does not create a fake PBIX. Power BI Desktop must open
and save the real PBIX/PBIP after the report definition has been built there.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime

from automation_common import locate, log_path, project_root, root


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", choices=["A", "B", "Both"], default="Both")
    args = parser.parse_args()
    base, project = root(), project_root()
    xlsx = locate("Assignment1_BISM2202_pizza_sell_data.xlsx")
    docx = locate("Data Visualization Using Microsoft Power BI Assessment Task Instructions 2026 Semester 2_BISM2202.docx")
    common = project / "COMMON"
    log = log_path("build_powerbi_project")
    commands = [
        [sys.executable, str(common / "analyze_assignment.py"), "--input", str(xlsx), "--output-dir", str(common)],
        [sys.executable, str(common / "build_deliverables.py"), "--source-docx", str(docx), "--source-xlsx", str(xlsx)],
    ]
    with log.open("w", encoding="utf-8") as stream:
        for command in commands:
            stream.write("COMMAND: " + subprocess.list2cmdline(command) + "\n")
            subprocess.run(command, check=True, stdout=stream, stderr=subprocess.STDOUT)
    versions = ["A", "B"] if args.version == "Both" else [args.version]
    for version in versions:
        folder = project / f"Version_{version}"
        (folder / "screenshots").mkdir(parents=True, exist_ok=True)
        (base / f"Student_{version}" / "screenshots").mkdir(parents=True, exist_ok=True)
    manifest = {
        "generated": datetime.now().isoformat(timespec="seconds"),
        "source_xlsx": str(xlsx), "source_docx": str(docx), "project": str(project),
        "versions": versions, "powerbi_table": "PizzaOrders",
        "pbix_policy": "Must be created and saved by genuine Microsoft Power BI Desktop; no fake PBIX is generated.",
    }
    (base / "automation" / "powerbi_project_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps(manifest, indent=2))
    print(f"Log: {log}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
