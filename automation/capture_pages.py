#!/usr/bin/env python3
"""Capture Q01-Q20 from the real Power BI Desktop window."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import time
from datetime import datetime

import mss
import mss.tools
from pywinauto import Application, keyboard

from automation_common import log_path, project_root


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", choices=["A", "B"], required=True)
    parser.add_argument("--delay", type=float, default=1.2)
    parser.add_argument("--keyboard-fallback", action="store_true", help="Start on Q01 and use Ctrl+PageDown between pages.")
    args = parser.parse_args()
    output = project_root() / f"Version_{args.version}" / "screenshots"
    output.mkdir(parents=True, exist_ok=True)
    app = Application(backend="uia").connect(path="PBIDesktop.exe", timeout=20)
    window = app.top_window()
    window.set_focus()
    window.maximize()
    page_controls = {}
    for control in window.descendants():
        title = control.window_text().strip()
        if re.fullmatch(r"Q(?:0[1-9]|1[0-9]|20)", title, re.I):
            page_controls[title.upper()] = control
    if len(page_controls) < 20 and not args.keyboard_fallback:
        raise RuntimeError(f"Power BI exposed only {len(page_controls)}/20 named page tabs. Rename pages Q01-Q20 or use --keyboard-fallback after selecting Q01.")
    rect = window.rectangle()
    monitor = {"left": rect.left, "top": rect.top, "width": rect.width(), "height": rect.height()}
    records = []
    with mss.mss() as capture:
        for number in range(1, 21):
            name = f"Q{number:02d}"
            if name in page_controls:
                page_controls[name].click_input()
            elif number > 1:
                keyboard.send_keys("^{PGDN}")
            time.sleep(args.delay)
            target = output / f"{name}.png"
            image = capture.grab(monitor)
            mss.tools.to_png(image.rgb, image.size, output=str(target))
            records.append({"page": name, "file": str(target), "sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "captured": datetime.now().isoformat(timespec="seconds"), "window_title": window.window_text()})
            print(f"Captured genuine Power BI window: {target}")
    metadata = output / "capture_metadata.json"
    metadata.write_text(json.dumps(records, indent=2), encoding="utf-8")
    log_path("capture_pages").write_text(json.dumps(records, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
