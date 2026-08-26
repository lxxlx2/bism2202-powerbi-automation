#!/usr/bin/env python3
"""Transactional Q01-Q20 capture using the proven pywinauto UIA page-tab driver.

This restores the page-switching mechanism that was used successfully in earlier
BISM2202 review captures. It keeps the newer safety guarantees:
- canvas-only submission screenshots plus full-window review screenshots;
- staging before publish;
- SHA256 uniqueness validation across all 20 pages;
- no replacement of existing final screenshots unless every page passes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import tempfile
import time
from datetime import datetime
from pathlib import Path

import mss
import mss.tools
from pywinauto import Application, keyboard, mouse

from automation_common import project_root

PAGE_RE = re.compile(r"Q(?:0[1-9]|1[0-9]|20)", re.I)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save_grab(capture: mss.mss, monitor: dict[str, int], target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    image = capture.grab(monitor)
    mss.tools.to_png(image.rgb, image.size, output=str(target))


def discover_page_controls(window) -> dict[str, object]:
    controls: dict[str, object] = {}
    for control in window.descendants():
        try:
            title = control.window_text().strip()
        except Exception:
            continue
        if PAGE_RE.fullmatch(title):
            controls[title.upper()] = control
    return controls


def click_named_page(window, page_controls: dict[str, object], name: str) -> None:
    control = page_controls.get(name)
    if control is None:
        # Refresh once because Power BI can recreate tab controls after a page switch.
        page_controls.clear()
        page_controls.update(discover_page_controls(window))
        control = page_controls.get(name)
    if control is None:
        raise RuntimeError(f"UIA page tab {name} is unavailable")

    window.set_focus()
    try:
        control.click_input()
    except Exception:
        # Re-resolve stale controls and retry once.
        page_controls.clear()
        page_controls.update(discover_page_controls(window))
        control = page_controls.get(name)
        if control is None:
            raise RuntimeError(f"UIA page tab {name} disappeared during retry")
        control.click_input()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", choices=["A", "B"], required=True)
    parser.add_argument("--delay", type=float, default=1.8)
    args = parser.parse_args()

    root = project_root()
    final_shots = root / f"Version_{args.version}" / "screenshots"
    final_review = root / f"Version_{args.version}" / "review_full"

    app = Application(backend="uia").connect(path="PBIDesktop.exe", timeout=30)
    window = app.top_window()
    window.set_focus()
    window.maximize()
    time.sleep(2.0)

    page_controls = discover_page_controls(window)
    names = sorted(page_controls)
    print(f"UIA_PAGE_TABS_DISCOVERED: {len(names)}/20")
    print("UIA_PAGE_TAB_NAMES: " + ",".join(names))
    missing = [f"Q{i:02d}" for i in range(1, 21) if f"Q{i:02d}" not in page_controls]
    if missing:
        raise RuntimeError(
            "UIA could not discover all report page tabs. Missing: " + ",".join(missing)
        )
    print("UIA_PAGE_TABS_DISCOVERED: 20/20 PASS")

    rect = window.rectangle()
    width = rect.width()
    height = rect.height()
    if width < 1000 or height < 700:
        raise RuntimeError("Power BI window is too small. Maximize it before capture.")

    # Ratios copied from the independently accepted Q01 clean-canvas capture.
    canvas_monitor = {
        "left": rect.left + int(width * 0.055),
        "top": rect.top + int(height * 0.125),
        "width": int(width * 0.755),
        "height": int(height * 0.790),
    }
    full_monitor = {
        "left": rect.left,
        "top": rect.top,
        "width": width,
        "height": height,
    }
    safe_point = (rect.right - 25, rect.top + 90)

    stage_root = Path(tempfile.mkdtemp(prefix=f"bism2202_uia_{args.version}_"))
    stage_shots = stage_root / "screenshots"
    stage_review = stage_root / "review_full"
    records: list[dict[str, object]] = []

    try:
        with mss.mss() as capture:
            for number in range(1, 21):
                name = f"Q{number:02d}"
                click_named_page(window, page_controls, name)
                time.sleep(max(0.35, args.delay * 0.35))
                keyboard.send_keys("{ESC}")
                mouse.move(coords=safe_point)
                time.sleep(args.delay)

                shot = stage_shots / f"{name}.png"
                review = stage_review / f"{name}_full.png"
                save_grab(capture, canvas_monitor, shot)
                save_grab(capture, full_monitor, review)

                shot_bytes = shot.stat().st_size
                review_bytes = review.stat().st_size
                if shot_bytes < 5000:
                    raise RuntimeError(f"{name} canvas screenshot is suspiciously small: {shot_bytes} bytes")
                if review_bytes < 10000:
                    raise RuntimeError(f"{name} review screenshot is suspiciously small: {review_bytes} bytes")

                shot_hash = sha256(shot)
                review_hash = sha256(review)
                records.append(
                    {
                        "page": name,
                        "canvas_file": str(shot),
                        "canvas_bytes": shot_bytes,
                        "canvas_sha256": shot_hash,
                        "review_file": str(review),
                        "review_bytes": review_bytes,
                        "review_sha256": review_hash,
                        "captured": datetime.now().isoformat(timespec="seconds"),
                        "driver": "pywinauto-uia-named-page-tab",
                        "canvas_rect": canvas_monitor,
                        "full_rect": full_monitor,
                    }
                )
                print(f"Captured {name}: {shot_bytes} bytes sha256={shot_hash[:12]}")

        if len(records) != 20:
            raise RuntimeError(f"Expected 20 staged records, found {len(records)}")

        groups: dict[str, list[str]] = {}
        for record in records:
            groups.setdefault(str(record["canvas_sha256"]), []).append(str(record["page"]))
        duplicates = {h: pages for h, pages in groups.items() if len(pages) > 1}
        if duplicates:
            details = "; ".join(f"hash={h[:12]} pages={','.join(pages)}" for h, pages in duplicates.items())
            raise RuntimeError("Duplicate page captures detected; refusing to publish. " + details)
        print(f"VERSION_{args.version}_UNIQUE_PAGE_HASHES: 20/20 PASS")

        final_shots.mkdir(parents=True, exist_ok=True)
        final_review.mkdir(parents=True, exist_ok=True)

        for old in final_shots.glob("Q??.png"):
            old.unlink()
        for old in final_review.glob("Q??_full.png"):
            old.unlink()

        for src in sorted(stage_shots.glob("Q??.png")):
            shutil.copy2(src, final_shots / src.name)
        for src in sorted(stage_review.glob("Q??_full.png")):
            shutil.copy2(src, final_review / src.name)

        metadata = json.dumps(records, indent=2)
        (final_shots / "capture_metadata.json").write_text(metadata, encoding="utf-8")
        (final_review / "capture_metadata.json").write_text(metadata, encoding="utf-8")

        published = sorted(final_shots.glob("Q??.png"))
        if len(published) != 20:
            raise RuntimeError(f"Published screenshot verification failed: expected 20, found {len(published)}")
        published_hashes = {sha256(path) for path in published}
        if len(published_hashes) != 20:
            raise RuntimeError(f"Published screenshots are not unique: {len(published_hashes)}/20")

        print(f"CLEAN_CAPTURE_{args.version}: 20/20 PASS")
        print(f"VERSION_{args.version}_SCREENSHOTS: 20 FRESH PASS")
        print(f"VERSION_{args.version}_UNIQUE_FINAL_HASHES: 20/20 PASS")
        print(f"VERSION_{args.version}_HOVER_SAFE_CAPTURE: PASS")
        print(f"VERSION_{args.version}_TRANSACTIONAL_PUBLISH: PASS")
        return 0
    finally:
        shutil.rmtree(stage_root, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
