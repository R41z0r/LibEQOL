#!/usr/bin/env python3
"""
Bump the SettingsLib composite version across all Settings files.

Composite scheme: version = major * 1_000_000 + minor * 1_000 + patch
This allows 3 digits each for minor/patch (0-999). Adjust constants if needed.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

COMPOSITE_MINOR_MULT = 1000
COMPOSITE_MAJOR_MULT = 1_000_000

VERSION_FILE = Path("scripts/settings-version.json")
TARGETS = [
    Path("LibEQOLEditMode.lua"),
    Path("LibEQOLSettingsMode.lua"),
    Path("LibEQOLSettingsMultiDropdown.lua"),
    Path("LibEQOLSettingsSoundDropdown.lua"),
    Path("LibEQOLSettingsColorOverrides.lua"),
]


def load_version() -> dict:
    if VERSION_FILE.exists():
        with VERSION_FILE.open() as fh:
            return json.load(fh)
    # Default seed
    return {"major": 2, "minor": 0, "patch": 0}


def save_version(ver: dict) -> None:
    VERSION_FILE.parent.mkdir(parents=True, exist_ok=True)
    with VERSION_FILE.open("w") as fh:
        json.dump(ver, fh, indent=2)
        fh.write("\n")


def composite(ver: dict) -> int:
    return (
        ver["major"] * COMPOSITE_MAJOR_MULT
        + ver["minor"] * COMPOSITE_MINOR_MULT
        + ver["patch"]
    )


def bump(ver: dict, level: str) -> dict:
    ver = dict(ver)
    if level == "major":
        ver["major"] += 1
        ver["minor"] = 0
        ver["patch"] = 0
    elif level == "minor":
        ver["minor"] += 1
        ver["patch"] = 0
    else:
        ver["patch"] += 1
    return ver


def update_file(path: Path, value: int) -> None:
    text = path.read_text()
    pattern = re.compile(r'("LibEQOLSettingsMode-1\.0"\s*,\s*)(\d+)')
    new_text, count = pattern.subn(r"\g<1>{}".format(value), text, count=1)
    if count == 0:
        raise SystemExit(f"No version marker found in {path}")
    path.write_text(new_text)


def main() -> None:
    level = "patch"
    if len(sys.argv) > 1:
        arg = sys.argv[1].lstrip("-").lower()
        if arg in ("major", "minor", "patch"):
            level = arg
    ver = load_version()
    ver = bump(ver, level)
    value = composite(ver)
    save_version(ver)
    for target in TARGETS:
        update_file(target, value)
    print(f"Updated SettingsLib version to {ver['major']}.{ver['minor']}.{ver['patch']} (composite {value})")


if __name__ == "__main__":
    main()
