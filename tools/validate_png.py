#!/usr/bin/env python3
"""Validate PNG files used by Railwright release packaging."""

from __future__ import annotations

import argparse
import struct
import sys
import zlib
from pathlib import Path

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class PngValidationError(ValueError):
    """Raised when PNG data is structurally invalid."""


def validate_png_bytes(data: bytes, label: str = "PNG") -> tuple[int, int]:
    """Validate PNG signature, chunk boundaries, CRCs, IHDR, and IEND."""
    if not data.startswith(PNG_SIGNATURE):
        raise PngValidationError(f"{label} does not have a valid PNG signature")

    offset = len(PNG_SIGNATURE)
    saw_ihdr = False
    saw_iend = False
    width = 0
    height = 0

    while offset < len(data):
        if offset + 8 > len(data):
            raise PngValidationError(f"{label} ends inside a PNG chunk header")

        length = struct.unpack(">I", data[offset : offset + 4])[0]
        chunk_type = data[offset + 4 : offset + 8]
        chunk_start = offset + 8
        chunk_end = chunk_start + length
        crc_end = chunk_end + 4

        if crc_end > len(data):
            name = chunk_type.decode("ascii", errors="replace")
            raise PngValidationError(f"{label} has a truncated {name} chunk")

        chunk_data = data[chunk_start:chunk_end]
        expected_crc = struct.unpack(">I", data[chunk_end:crc_end])[0]
        actual_crc = zlib.crc32(chunk_type)
        actual_crc = zlib.crc32(chunk_data, actual_crc) & 0xFFFFFFFF

        if actual_crc != expected_crc:
            name = chunk_type.decode("ascii", errors="replace")
            raise PngValidationError(f"{label} has an invalid CRC in its {name} chunk")

        if not saw_ihdr:
            if chunk_type != b"IHDR" or length != 13:
                raise PngValidationError(f"{label} must start with a 13-byte IHDR chunk")

            width, height = struct.unpack(">II", chunk_data[:8])
            if width <= 0 or height <= 0:
                raise PngValidationError(f"{label} has invalid dimensions {width}x{height}")
            saw_ihdr = True

        if chunk_type == b"IEND":
            if length != 0:
                raise PngValidationError(f"{label} has an invalid IEND chunk")
            saw_iend = True
            if crc_end != len(data):
                raise PngValidationError(f"{label} contains trailing data after IEND")
            break

        offset = crc_end

    if not saw_ihdr:
        raise PngValidationError(f"{label} is missing an IHDR chunk")
    if not saw_iend:
        raise PngValidationError(f"{label} is missing an IEND chunk")

    return width, height


def validate_png_file(path: Path) -> tuple[int, int]:
    if not path.is_file():
        raise PngValidationError(f"Missing required PNG file: {path}")
    return validate_png_bytes(path.read_bytes(), str(path))


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Railwright PNG assets")
    parser.add_argument("paths", nargs="+", type=Path, help="PNG files to validate")
    args = parser.parse_args()

    try:
        for path in args.paths:
            width, height = validate_png_file(path)

            if path.name == "railwright-shortcut-x56.png" and (width, height) != (56, 56):
                raise PngValidationError(
                    f"{path} must be exactly 56x56 pixels, got {width}x{height}"
                )

            print(f"Validated {path}: {width}x{height}")
    except PngValidationError as exc:
        print(f"PNG validation failed: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
