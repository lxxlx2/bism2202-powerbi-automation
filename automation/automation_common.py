from __future__ import annotations

import os
from datetime import datetime
from pathlib import Path


def root() -> Path:
    configured = os.environ.get("BISM2202_ROOT")
    return Path(configured).expanduser().resolve() if configured else Path(__file__).resolve().parents[1]


def log_path(name: str) -> Path:
    folder = root() / "automation" / "logs"
    folder.mkdir(parents=True, exist_ok=True)
    return folder / f"{name}_{datetime.now():%Y%m%d_%H%M%S}.log"


def locate(filename: str) -> Path:
    base = root()
    candidates = [
        base / "input" / filename,
        base / "INPUTS" / filename,
        base / filename,
        base / "PROJECT" / "BISM2202_OUTPUT" / filename,
        Path.home() / "Downloads" / filename,
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    raise FileNotFoundError(f"Cannot locate {filename}; checked: {candidates}")


def project_root() -> Path:
    base = root()
    candidates = [base / "project", base / "PROJECT" / "BISM2202_OUTPUT", base / "BISM2202_OUTPUT"]
    for candidate in candidates:
        if (candidate / "COMMON").is_dir():
            return candidate.resolve()
    raise FileNotFoundError("Cannot find project/COMMON under BISM2202 root.")
