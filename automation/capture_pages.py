#!/usr/bin/env python3
"""Capture Q01-Q20 from a genuine Power BI Desktop window.

Two image sets are created:
1. screenshots/Qxx.png: canvas-only images intended for the final report.
2. review_full/Qxx_full.png: full Power BI window images intended for QA/review.

The full-window set may contain localized Power BI UI text. It is never intended
for submission. The canvas-only set is what the report generator should use.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import time
from datetime import datetime
from pathlib import Path

import mss
import mss.tools
from pywinauto import Application, keyboard

from automation_common import log_path, project_root


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _save_grab(capture: mss.mss, monitor: dict[str, int], target: Path) -> None:
    image = capture.grab(monitor)
    mss.tools.to_png(image.rgb, image.size, output=str(target))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", choices=["A", "B"], required=True)
    parser.add_argument("--delay", type=float, default=1.6)
    parser.add_argument(
        "--keyboard-fallback",
        action="store_true",
        help="After selecting Q01, use Ctrl+PageDown between pages.",
    )
    parser.add_argument(
        "--canvas-left",
        type=float,
        default=0.025,
        help="Canvas crop left ratio relative to the Power BI window.",
    )
    parser.add_argument("--canvas-top", type=float, default=0.17)
    parser.add_argument("--canvas-width", type=float, default=0.65)
    parser.add_argument("--canvas-height", type=float, default=0.69)
    args = parser.parse_args()

    root = project_root()
    output = root / f"Version_{args.version}" / "screenshots"
    review = root / f"Version_{args.version}" / "review_full"
    output.mkdir(parents=True, exist_ok=True)
    review.mkdir(parents=True, exist_ok=True)

    app = Application(backend="uia").connect(path="PBIDesktop.exe", timeout=30)
    window = app.top_window()
    window.set_focus()
    window.maximize()
    time.sleep(2.0)

    page_controls = {}
    for control in window.descendants():
        title = control.window_text().strip()
        if re.fullmatch(r"Q(?:0[1-9]|1[0-9]|20)", title, re.I):
            page_controls[title.upper()] = control

    if "Q01" not in page_controls and not args.keyboard_fallback:
        raise RuntimeError(
            f"Power BI exposed {len(page_controls)}/20 named page tabs and Q01 was not found. "
            "Open the generated Q01-Q20 report or use --keyboard-fallback after selecting Q01."
        )

    rect = window.rectangle()
    full_monitor = {
        "left": rect.left,
        "top": rect.top,
        "width": rect.width(),
        "height": rect.height(),
    }
    canvas_monitor = {
        "left": rect.left + int(rect.width() * args.canvas_left),
        "top": rect.top + int(rect.height() * args.canvas_top),
        "width": int(rect.width() * args.canvas_width),
        "height": int(rect.height() * args.canvas_height),
    }

    records: list[dict[str, object]] = []
    with mss.mss() as capture:
        for number in range(1, 21):
            name = f"Q{number:02d}"
            if number == 1 and name in page_controls:
                page_controls[name].click_input()
            elif not args.keyboard_fallback and name in page_controls:
                try:
                    page_controls[name].click_input()
                except Exception:
                    keyboard.send_keys("^{PGDN}")
            elif number > 1:
                keyboard.send_keys("^{PGDN}")

            time.sleep(args.delay)

            final_target = output / f"{name}.png"
            review_target = review / f"{name}_full.png"
            _save_grab(capture, canvas_monitor, final_target)
            _save_grab(capture, full_monitor, review_target)

            record = {
                "page": name,
                "canvas_file": str(final_target),
                "canvas_sha256": _sha256(final_target),
                "review_file": str(review_target),
                "review_sha256": _sha256(review_target),
                "captured": datetime.now().isoformat(timespec="seconds"),
                "window_title": window.window_text(),
                "canvas_rect": canvas_monitor,
                "full_rect": full_monitor,
            }
            records.append(record)
            print(f"Captured {name}: final={final_target} review={review_target}")

    metadata = review / "capture_metadata.json"
    metadata.write_text(json.dumps(records, indent=2), encoding="utf-8")
    log_path("capture_pages").write_text(json.dumps(records, indent=2), encoding="utf-8")
    print(f"Captured {len(records)} pages for Version {args.version}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
