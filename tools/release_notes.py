#!/usr/bin/env python3
"""Extract one Factorio changelog entry and render it as GitHub-flavoured Markdown."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHANGELOG = ROOT / "changelog.txt"
SEPARATOR = re.compile(r"^-{20,}\s*$")
VERSION_LINE = re.compile(r"^Version:\s*(.+?)\s*$")
DATE_LINE = re.compile(r"^Date:\s*(.+?)\s*$")
CATEGORY_LINE = re.compile(r"^\s{2}([^\s].*?):\s*$")
BULLET_LINE = re.compile(r"^\s{4}-\s+(.*)$")


def split_entries(text: str) -> list[list[str]]:
    entries: list[list[str]] = []
    current: list[str] = []

    for line in text.splitlines():
        if SEPARATOR.match(line):
            if current:
                entries.append(current)
                current = []
            continue
        if line.strip() or current:
            current.append(line.rstrip())

    if current:
        entries.append(current)

    return entries


def find_entry(version: str) -> list[str]:
    try:
        text = CHANGELOG.read_text(encoding="utf-8")
    except OSError as exc:
        raise RuntimeError(f"Could not read {CHANGELOG}: {exc}") from exc

    for entry in split_entries(text):
        for line in entry:
            match = VERSION_LINE.match(line)
            if match and match.group(1) == version:
                return entry

    raise RuntimeError(f"changelog.txt does not contain an entry for version {version}.")


def render_markdown(entry: list[str]) -> str:
    version = None
    date = None
    body: list[str] = []

    for line in entry:
        version_match = VERSION_LINE.match(line)
        if version_match:
            version = version_match.group(1)
            continue

        date_match = DATE_LINE.match(line)
        if date_match:
            date = date_match.group(1)
            continue

        category_match = CATEGORY_LINE.match(line)
        if category_match:
            if body and body[-1] != "":
                body.append("")
            body.append(f"### {category_match.group(1)}")
            body.append("")
            continue

        bullet_match = BULLET_LINE.match(line)
        if bullet_match:
            body.append(f"- {bullet_match.group(1)}")
            continue

        if line.strip():
            body.append(line.strip())

    if not version:
        raise RuntimeError("Selected changelog entry has no Version line.")

    result = [f"## Railwright {version}"]
    if date:
        result.extend(["", f"Released: {date}"])
    if body:
        result.extend(["", *body])

    return "\n".join(result).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("version", help="Version to extract, for example 0.2.1")
    args = parser.parse_args()

    try:
        entry = find_entry(args.version)
        sys.stdout.write(render_markdown(entry))
    except RuntimeError as exc:
        print(f"Release-note generation failed: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
