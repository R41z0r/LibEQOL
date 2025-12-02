#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

# Composite version scheme: major * 1_000_000 + minor * 1_000 + patch
WIDTH_MINOR = 3
WIDTH_PATCH = 3
MULT_MINOR = 1000
MULT_MAJOR = 1000000

VERSION_FILE = Path("scripts/settings-version.json")
TARGETS = [
    Path("LibEQOLSettingsMode.lua"),
    Path("LibEQOLSettingsMultiDropdown.lua"),
    Path("LibEQOLSettingsSoundDropdown.lua"),
    Path("LibEQOLSettingsColorOverrides.lua"),
]


def load_version():
    if VERSION_FILE.exists():
        with VERSION_FILE.open() as fh:
            return json.load(fh)
    # Default seed for major/minor/patch
    return {"major": 2, "minor": 0, "patch": 0}


def save_version(ver):
    VERSION_FILE.parent.mkdir(parents=True, exist_ok=True)
    with VERSION_FILE.open("w") as fh:
        json.dump(ver, fh, indent=2)
        fh.write("\n")


def composite(ver):
    return ver["major"] * MULT_MAJOR + ver["minor"] * MULT_MINOR + ver["patch"]


def bump(ver, level):
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


def update_file(path, value):
    text = path.read_text()
    pattern = r'(LibEQOLSettingsMode-1\.0",\s*)(\d+)'
    repl = r"\\1{}".format(value)
    new_text, count = re.subn(pattern, repl, text)
    if count == 0:
        raise SystemExit(f"No version marker found in {path}")
    path.write_text(new_text)


def main():
    level = "patch"
    if len(sys.argv) > 1:
        if sys.argv[1] in ("--major", "major"):
            level = "major"
        elif sys.argv[1] in ("--minor", "minor"):
            level = "minor"
    ver = load_version()
    ver = bump(ver, level)
    value = composite(ver)
    save_version(ver)
    for target in TARGETS:
        update_file(target, value)
    print(f"Updated version to {ver['major']}.{ver['minor']}.{ver['patch']} (composite {value})")


if __name__ == "__main__":
    main()
