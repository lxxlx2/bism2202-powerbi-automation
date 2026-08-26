#!/usr/bin/env python3
"""Capture Q01-Q20 from Power BI with the mouse moved away from the canvas.

This is the submission-safe capture variant. It prevents hover/crosshair states
from being frozen into screenshots by moving the pointer to a safe UI location
and pressing Escape before every capture.
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
from pywinauto import Application, keyboard, mouse

from automation_common import log_path, project_root


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _save_grab(capture: mss.mss, monitor: dict[str, int], target: Path) -> None:
    image = capture.grab(monitor)
    mss.tools.to_png(image.rgb, image.size, output=str(target))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", choices=["A", "B"], required=True)
    parser.add_argument("--delay", type=float, default=1.8)
    parser.add_argument("--canvas-left", type=float, default=0.025)
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

    if "Q01" not in page_controls:
        raise RuntimeError(f"Power BI exposed {len(page_controls)}/20 named page tabs and Q01 was not found")

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

    # Safe pointer location: top-right UI chrome, outside the report canvas crop.
    safe_point = (
        rect.left + int(rect.width() * 0.94),
        rect.top + int(rect.height() * 0.11),
    )

    records: list[dict[str, object]] = []
    with mss.mss() as capture:
        for number in range(1, 21):
            name = f"Q{number:02d}"
            control = page_controls.get(name)
            if control is None:
                raise RuntimeError(f"Missing page control {name}")
            try:
                control.click_input()
            except Exception:
                window.set_focus()
                if number == 1:
                    raise
                keyboard.send_keys("^{PGDN}")

            # Clear any active tooltip / selection / hover state before capture.
            keyboard.send_keys("{ESC}")
            mouse.move(coords=safe_point)
            time.sleep(args.delay)

            final_target = output / f"{name}.png"
            review_target = review / f"{name}_full.png"
            _save_grab(capture, canvas_monitor, final_target)
            _save_grab(capture, full_monitor, review_target)

            if final_target.stat().st_size < 5000:
                raise RuntimeError(f"{name} canvas screenshot is suspiciously small: {final_target.stat().st_size} bytes")

            record = {
                "page": name,
                "canvas_file": str(final_target),
                "canvas_sha256": _sha256(final_target),
                "canvas_bytes": final_target.stat().st_size,
                "review_file": str(review_target),
                "review_sha256": _sha256(review_target),
                "captured": datetime.now().isoformat(timespec="seconds"),
                "window_title": window.window_text(),
                "canvas_rect": canvas_monitor,
                "full_rect": full_monitor,
                "safe_pointer": safe_point,
            }
            records.append(record)
            print(f"Captured {name}: {final_target.stat().st_size} bytes")

    if len(records) != 20:
        raise RuntimeError(f"Expected 20 captures, got {len(records)}")

    metadata_text = json.dumps(records, indent=2)
    (review / "capture_metadata.json").write_text(metadata_text, encoding="utf-8")
    (output / "capture_metadata.json").write_text(metadata_text, encoding="utf-8")
    log_path("capture_pages_clean").write_text(metadata_text, encoding="utf-8")
    print(f"CLEAN_CAPTURE_{args.version}: 20/20 PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
