#!/usr/bin/env python3
"""Validate that a PBIX exists and can be reopened by Power BI Desktop."""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import time
from pathlib import Path

from pywinauto import Application

from automation_common import log_path, project_root


def find_powerbi() -> Path | None:
    roots = [Path(os.environ.get("LOCALAPPDATA", "")), Path(os.environ.get("ProgramFiles", "")), Path(os.environ.get("ProgramFiles(x86)", ""))]
    relatives = [Path("Microsoft/Power BI Desktop/bin/PBIDesktop.exe"), Path("Microsoft Power BI Desktop/bin/PBIDesktop.exe")]
    for base in roots:
        for relative in relatives:
            candidate = base / relative
            if candidate.is_file(): return candidate
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", choices=["A", "B"], required=True)
    parser.add_argument("--reopen", action="store_true")
    args = parser.parse_args()
    folder = project_root() / f"Version_{args.version}"
    candidates = [folder / f"BISM2202_Assignment_{args.version}.pbix", folder / "BISM2202_Assignment.pbix"]
    pbix = next((path for path in candidates if path.is_file()), candidates[0])
    issues = []
    if not pbix.is_file(): issues.append(f"Missing PBIX: {pbix}")
    elif pbix.stat().st_size < 100_000: issues.append(f"PBIX is unexpectedly small: {pbix.stat().st_size} bytes")
    reopened = False
    if args.reopen and not issues:
        exe = find_powerbi()
        if not exe: issues.append("PBIDesktop.exe not found for reopen test.")
        else:
            subprocess.Popen([str(exe), str(pbix)])
            deadline = time.time() + 180
            while time.time() < deadline:
                try:
                    app = Application(backend="uia").connect(path="PBIDesktop.exe", timeout=3)
                    title = app.top_window().window_text()
                    if pbix.stem.lower() in title.lower(): reopened = True; break
                except Exception: pass
                time.sleep(3)
            if not reopened: issues.append("Power BI did not expose a matching reopened window within 180 seconds.")
    result = {"status": "PASS" if not issues else "FAIL", "pbix": str(pbix), "bytes": pbix.stat().st_size if pbix.is_file() else 0, "reopened": reopened, "issues": issues}
    log_path("validate_powerbi").with_suffix(".json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if not issues else 2


if __name__ == "__main__":
    raise SystemExit(main())
