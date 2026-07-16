#!/usr/bin/env python3
"""Build a Factorio-compatible Railwright ZIP archive.

The resulting archive contains a single top-level directory named
`<mod-name>_<version>`, as required for normal Factorio mod ZIPs.
"""

from __future__ import annotations

import json
import shutil
import sys
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
INFO_PATH = ROOT / "info.json"
DIST_DIR = ROOT / "dist"

EXCLUDED_TOP_LEVEL = {
    ".git",
    ".github",
    ".idea",
    ".vscode",
    "dist",
    "tools",
    "__pycache__",
}

EXCLUDED_FILES = {
    ".DS_Store",
    "Thumbs.db",
}

# The Factorio Mod Portal rejects archives containing executable tooling.
# Keep build and maintenance scripts in Git, but never distribute them in the mod.
FORBIDDEN_PORTAL_SUFFIXES = {".exe", ".bat", ".ps1", ".sh", ".py"}


def load_mod_metadata() -> tuple[str, str]:
    try:
        info = json.loads(INFO_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"Could not read {INFO_PATH}: {exc}") from exc

    name = info.get("name")
    version = info.get("version")
    if not isinstance(name, str) or not name:
        raise RuntimeError("info.json must contain a non-empty string 'name'.")
    if not isinstance(version, str) or not version:
        raise RuntimeError("info.json must contain a non-empty string 'version'.")

    return name, version


def should_include(path: Path) -> bool:
    relative = path.relative_to(ROOT)
    if not relative.parts:
        return False
    if relative.parts[0] in EXCLUDED_TOP_LEVEL:
        return False
    if path.name in EXCLUDED_FILES:
        return False
    if path.suffix.lower() in FORBIDDEN_PORTAL_SUFFIXES | {".pyc", ".pyo"}:
        return False
    return path.is_file()


def build_archive() -> Path:
    mod_name, version = load_mod_metadata()
    package_root = f"{mod_name}_{version}"
    archive_path = DIST_DIR / f"{package_root}.zip"

    if DIST_DIR.exists():
        shutil.rmtree(DIST_DIR)
    DIST_DIR.mkdir(parents=True)

    files = sorted(
        (path for path in ROOT.rglob("*") if should_include(path)),
        key=lambda path: path.relative_to(ROOT).as_posix(),
    )

    if INFO_PATH not in files:
        raise RuntimeError("info.json would not be included in the package.")

    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for source_path in files:
            relative = PurePosixPath(source_path.relative_to(ROOT).as_posix())
            archive_name = str(PurePosixPath(package_root) / relative)
            archive.write(source_path, archive_name)

    print(f"Built {archive_path.relative_to(ROOT).as_posix()}")
    print(f"Package root: {package_root}")
    print(f"Files included: {len(files)}")
    return archive_path


def main() -> int:
    try:
        build_archive()
    except Exception as exc:  # Packaging errors should fail CI with a clear message.
        print(f"Packaging failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
