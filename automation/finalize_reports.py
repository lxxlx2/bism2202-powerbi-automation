#!/usr/bin/env python3
"""Insert genuine screenshots into Word and assemble Student_A/Student_B."""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import zipfile

from automation_common import locate, log_path, project_root, root


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", choices=["A", "B", "Both"], default="Both")
    args = parser.parse_args()
    base, project = root(), project_root()
    xlsx = locate("Assignment1_BISM2202_pizza_sell_data.xlsx")
    docx = locate("Data Visualization Using Microsoft Power BI Assessment Task Instructions 2026 Semester 2_BISM2202.docx")
    subprocess.run([sys.executable, str(project / "COMMON" / "build_deliverables.py"), "--source-docx", str(docx), "--source-xlsx", str(xlsx)], check=True)
    versions = ["A", "B"] if args.version == "Both" else [args.version]
    issues = []
    for version in versions:
        source = project / f"Version_{version}"
        destination = base / f"Student_{version}"
        destination.mkdir(parents=True, exist_ok=True)
        pbix_candidates = [source / f"BISM2202_Assignment_{version}.pbix", source / "BISM2202_Assignment.pbix"]
        pbix = next((p for p in pbix_candidates if p.is_file()), pbix_candidates[0])
        report = source / f"BISM2202_Report_{version}.docx"
        screenshots = source / "screenshots"
        if not pbix.is_file(): issues.append(f"Version {version}: missing genuine PBIX")
        else: shutil.copy2(pbix, destination / "BISM2202_Assignment.pbix")
        if not report.is_file(): issues.append(f"Version {version}: missing Word report")
        else:
            with zipfile.ZipFile(report) as archive:
                media = [n for n in archive.namelist() if n.startswith("word/media/")]
            if len(media) < 20: issues.append(f"Version {version}: Word has only {len(media)} embedded images")
            shutil.copy2(report, destination / "BISM2202_Report.docx")
        if screenshots.is_dir():
            target = destination / "screenshots"
            target.mkdir(exist_ok=True)
            for number in range(1, 21):
                image = screenshots / f"Q{number:02d}.png"
                if not image.is_file(): issues.append(f"Version {version}: missing {image.name}")
                else: shutil.copy2(image, target / image.name)
    result = "PASS" if not issues else "FAIL"
    text = result + "\n" + "\n".join(issues) + "\n"
    log_path("finalize_reports").write_text(text, encoding="utf-8")
    print(text)
    return 0 if not issues else 2


if __name__ == "__main__":
    raise SystemExit(main())
