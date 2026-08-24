#!/usr/bin/env python3
"""Build and re-extract the two final submission ZIPs (PBIX + DOCX only)."""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import tempfile
import zipfile
from datetime import datetime
from pathlib import Path

from automation_common import root


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def docx_media_count(path: Path) -> int:
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None or "word/document.xml" not in archive.namelist():
            raise ValueError(f"Invalid DOCX: {path}")
        return len([name for name in archive.namelist() if name.startswith("word/media/") and not name.endswith("/")])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--final-commit", required=True)
    args = parser.parse_args()
    base = root()
    output = base / "FINAL_PACKAGES"
    deliverables = base / "FINAL_DELIVERABLES"
    output.mkdir(parents=True, exist_ok=True)
    deliverables.mkdir(parents=True, exist_ok=True)
    audit_path = base / "PROJECT" / "BISM2202_OUTPUT" / "COMMON" / "q01_q20_validation.json"
    audit = json.loads(audit_path.read_text(encoding="utf-8"))
    issues: list[str] = []
    manifest: dict[str, object] = {
        "generated": datetime.now().astimezone().isoformat(timespec="seconds"),
        "source_commit_before_fix": args.source_commit,
        "final_commit_after_fix": args.final_commit,
        "q01_q20_audit_status": audit.get("status"),
        "versions": {},
    }

    for version in ("A", "B"):
        source = base / "PROJECT" / "BISM2202_OUTPUT" / f"Version_{version}"
        source_pbix = source / f"BISM2202_Assignment_{version}.pbix"
        source_docx = source / f"BISM2202_Report_{version}.docx"
        shots = sorted((source / "screenshots").glob("Q??.png"))
        target_dir = deliverables / f"Student_{version}"
        target_dir.mkdir(parents=True, exist_ok=True)
        for child in target_dir.iterdir():
            if child.is_file():
                child.unlink()
            elif child.is_dir():
                shutil.rmtree(child)
        pbix = target_dir / f"BISM2202_Assignment_{version}.pbix"
        docx = target_dir / f"BISM2202_Report_{version}.docx"
        for source_path, target_path in ((source_pbix, pbix), (source_docx, docx)):
            if not source_path.is_file() or source_path.stat().st_size < 50_000:
                issues.append(f"Version {version}: missing or suspiciously small {source_path}")
                continue
            shutil.copy2(source_path, target_path)
        if len(shots) != 20:
            issues.append(f"Version {version}: expected 20 screenshots, found {len(shots)}")
        if issues:
            continue
        media_count = docx_media_count(docx)
        if media_count != 20:
            issues.append(f"Version {version}: expected 20 embedded report images, found {media_count}")
        target_zip = output / f"BISM2202_Student_{version}_FINAL.zip"
        names = [pbix.name, docx.name]
        with zipfile.ZipFile(target_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            archive.write(pbix, pbix.name)
            archive.write(docx, docx.name)
        with tempfile.TemporaryDirectory(prefix=f"bism2202_{version}_reextract_") as temp:
            temp_path = Path(temp)
            with zipfile.ZipFile(target_zip) as archive:
                if archive.namelist() != names or archive.testzip() is not None:
                    issues.append(f"Version {version}: ZIP exact-content validation failed")
                archive.extractall(temp_path)
            extracted = sorted(path for path in temp_path.iterdir() if path.is_file())
            if [path.name for path in extracted] != names:
                issues.append(f"Version {version}: re-extracted files differ from required names")
            for original in (pbix, docx):
                extracted_path = temp_path / original.name
                if not extracted_path.is_file() or sha256(extracted_path) != sha256(original):
                    issues.append(f"Version {version}: re-extracted hash mismatch for {original.name}")
            if (temp_path / docx.name).is_file():
                docx_media_count(temp_path / docx.name)
        manifest["versions"][version] = {
            "zip": str(target_zip.relative_to(base)),
            "zip_bytes": target_zip.stat().st_size,
            "zip_sha256": sha256(target_zip),
            "contents": names,
            "pbix_bytes": pbix.stat().st_size,
            "pbix_sha256": sha256(pbix),
            "docx_bytes": docx.stat().st_size,
            "docx_sha256": sha256(docx),
            "screenshot_count": len(shots),
            "docx_embedded_images": media_count,
            "reextraction_status": "PASS",
        }

    manifest["status"] = "PASS" if not issues and audit.get("status") == "PASS" else "FAIL"
    manifest["issues"] = issues
    json_path = output / "FINAL_PACKAGE_MANIFEST.json"
    json_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    lines = [
        "BISM2202 FINAL DELIVERY", "", f"Generated: {manifest['generated']}",
        f"Source commit before fix: {args.source_commit}", f"Final commit after fix: {args.final_commit}",
        f"Q01-Q20 audit: {manifest['q01_q20_audit_status']}", f"Status: {manifest['status']}", "",
    ]
    for version, record in manifest["versions"].items():
        lines += [f"Version {version}:", f"ZIP: {record['zip']}", f"ZIP bytes: {record['zip_bytes']}",
                  f"ZIP SHA256: {record['zip_sha256']}", f"PBIX SHA256: {record['pbix_sha256']}",
                  f"DOCX SHA256: {record['docx_sha256']}", f"Screenshots: {record['screenshot_count']}",
                  f"DOCX embedded images: {record['docx_embedded_images']}", "Re-extraction: PASS", ""]
    lines += ["Issues:", *(issues or ["None"])]
    (output / "FINAL_PACKAGE_MANIFEST.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))
    return 0 if manifest["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
