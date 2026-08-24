#!/usr/bin/env python3
"""Create the two submission ZIPs containing only PBIX + DOCX."""
from __future__ import annotations

import hashlib
import json
import zipfile
from datetime import datetime
from pathlib import Path

from automation_common import root


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> int:
    base = root()
    output = base / "FINAL_PACKAGES"
    output.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, object] = {"generated": datetime.now().astimezone().isoformat(timespec="seconds"), "versions": {}}
    issues: list[str] = []

    for version in ("A", "B"):
        version_issues: list[str] = []
        student = base / f"Student_{version}"
        pbix = student / "BISM2202_Assignment.pbix"
        docx = student / "BISM2202_Report.docx"
        for path in (pbix, docx):
            if not path.is_file() or path.stat().st_size < 50_000:
                version_issues.append(f"Missing or suspiciously small: {path}")
        if version_issues:
            issues.extend(version_issues)
            continue

        for path in (pbix, docx):
            try:
                with zipfile.ZipFile(path) as archive:
                    if archive.testzip():
                        version_issues.append(f"Corrupt Office/Power BI package: {path}")
            except zipfile.BadZipFile:
                version_issues.append(f"Not a valid ZIP-based package: {path}")
        with zipfile.ZipFile(docx) as archive:
            media = [name for name in archive.namelist() if name.startswith("word/media/") and not name.endswith("/")]
        if len(media) < 20:
            version_issues.append(f"Student {version} report has only {len(media)} embedded images.")

        target = output / f"BISM2202_Student_{version}_FINAL.zip"
        with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            archive.write(pbix, "BISM2202_Assignment.pbix")
            archive.write(docx, "BISM2202_Report.docx")
        with zipfile.ZipFile(target) as archive:
            names = archive.namelist()
            corrupt = archive.testzip()
        if names != ["BISM2202_Assignment.pbix", "BISM2202_Report.docx"] or corrupt:
            version_issues.append(f"Student {version} ZIP content validation failed: {names}, corrupt={corrupt}")

        issues.extend(version_issues)

        manifest["versions"][version] = {
            "zip": str(target.relative_to(base)),
            "zip_bytes": target.stat().st_size,
            "zip_sha256": sha256(target),
            "contents": names,
            "pbix_bytes": pbix.stat().st_size,
            "pbix_sha256": sha256(pbix),
            "docx_bytes": docx.stat().st_size,
            "docx_sha256": sha256(docx),
            "docx_embedded_images": len(media),
        }

    manifest["status"] = "PASS" if not issues else "FAIL"
    manifest["issues"] = issues
    json_path = output / "FINAL_PACKAGE_MANIFEST.json"
    json_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    text_lines = ["BISM2202 FINAL DELIVERY", "", f"Generated: {manifest['generated']}", f"Status: {manifest['status']}", ""]
    for version, record in manifest["versions"].items():
        text_lines += [
            f"Version {version}:",
            f"ZIP: {record['zip']}",
            "Contents: BISM2202_Assignment.pbix, BISM2202_Report.docx",
            f"ZIP bytes: {record['zip_bytes']}",
            f"ZIP SHA256: {record['zip_sha256']}",
            f"PBIX SHA256: {record['pbix_sha256']}",
            f"DOCX SHA256: {record['docx_sha256']}",
            f"DOCX embedded images: {record['docx_embedded_images']}",
            "",
        ]
    if issues:
        text_lines += ["Issues:", *issues]
    (output / "FINAL_PACKAGE_MANIFEST.txt").write_text("\n".join(text_lines) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))
    return 0 if not issues else 2


if __name__ == "__main__":
    raise SystemExit(main())
