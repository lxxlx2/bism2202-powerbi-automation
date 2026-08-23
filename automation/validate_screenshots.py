#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageStat

from automation_common import log_path, project_root


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", choices=["A", "B"], required=True)
    args = parser.parse_args()
    folder = project_root() / f"Version_{args.version}" / "screenshots"
    metadata_file = folder / "capture_metadata.json"
    issues, records, hashes = [], [], set()
    if not metadata_file.is_file():
        issues.append("capture_metadata.json is missing; screenshots cannot be traced to capture_pages.py.")
    for number in range(1, 21):
        path = folder / f"Q{number:02d}.png"
        if not path.is_file(): issues.append(f"Missing {path.name}"); continue
        try:
            with Image.open(path) as image:
                image.verify()
            with Image.open(path) as image:
                width, height = image.size
                stat = ImageStat.Stat(image.convert("L"))
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if width < 1600 or height < 900: issues.append(f"{path.name} is only {width}x{height}.")
            if stat.stddev[0] < 8: issues.append(f"{path.name} has unusually little visual variation.")
            if digest in hashes: issues.append(f"{path.name} duplicates another screenshot exactly.")
            hashes.add(digest)
            records.append({"file": path.name, "width": width, "height": height, "sha256": digest})
        except Exception as exc: issues.append(f"Unreadable {path.name}: {exc}")
    result = {"status": "PASS" if not issues else "FAIL", "count": len(records), "issues": issues, "screenshots": records}
    report = log_path("validate_screenshots").with_suffix(".json")
    report.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if not issues else 2


if __name__ == "__main__":
    raise SystemExit(main())
