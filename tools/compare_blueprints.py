#!/usr/bin/env python3
"""Compare Factorio blueprint entity geometry while ignoring global translation.

Inputs may be Factorio blueprint strings, files containing blueprint strings, or
JSON files containing either a full blueprint object or an entity array.
Entity-number ordering is intentionally ignored.
"""

from __future__ import annotations

import argparse
import base64
from collections import Counter, defaultdict
import json
from pathlib import Path
import sys
import zlib

PRECISION = 6
EXPORT_MARKER = "[Railwright][blueprint-debug][export] "


def rounded(value: float | int | None) -> float:
    return round(float(value or 0), PRECISION)


def load_text(source: str) -> str:
    path = Path(source)
    if path.is_file():
        return path.read_text(encoding="utf-8").strip()
    return source.strip()


def extract_export_from_log(text: str) -> str | None:
    exports = [
        line.split(EXPORT_MARKER, 1)[1].strip()
        for line in text.splitlines()
        if EXPORT_MARKER in line
    ]
    return exports[-1] if exports else None


def decode_blueprint_string(value: str) -> dict:
    if not value.startswith("0"):
        raise ValueError("Factorio blueprint strings must start with version marker '0'.")

    compressed = base64.b64decode(value[1:])
    return json.loads(zlib.decompress(compressed).decode("utf-8"))


def load_payload(source: str):
    text = load_text(source)
    exported = extract_export_from_log(text)
    if exported:
        text = exported

    if text.startswith("0"):
        return decode_blueprint_string(text)

    return json.loads(text)


def extract_entities(payload) -> list[dict]:
    if isinstance(payload, list):
        return payload

    if not isinstance(payload, dict):
        raise ValueError("Input must decode to a blueprint object, blueprint wrapper, or entity array.")

    if "blueprint" in payload:
        blueprint = payload["blueprint"]
    else:
        blueprint = payload

    entities = blueprint.get("entities")
    if entities is None:
        raise ValueError("No blueprint entities found in input.")
    return entities


def feature(entity: dict) -> tuple[str, int, float | None]:
    orientation = entity.get("orientation")
    return (
        entity.get("name", ""),
        int(entity.get("direction", 0)),
        None if orientation is None else rounded(orientation),
    )


def position(entity: dict) -> tuple[float, float]:
    pos = entity.get("position") or {}
    return rounded(pos.get("x", 0)), rounded(pos.get("y", 0))


def entity_key(entity: dict, dx: float = 0, dy: float = 0) -> tuple:
    x, y = position(entity)
    return (*feature(entity), rounded(x + dx), rounded(y + dy))


def candidate_translations(left: list[dict], right: list[dict]) -> Counter:
    left_by_feature: dict[tuple, list[tuple[float, float]]] = defaultdict(list)
    right_by_feature: dict[tuple, list[tuple[float, float]]] = defaultdict(list)

    for entity in left:
        left_by_feature[feature(entity)].append(position(entity))
    for entity in right:
        right_by_feature[feature(entity)].append(position(entity))

    candidates: Counter = Counter()
    for shared_feature in sorted(set(left_by_feature) & set(right_by_feature), key=str):
        for left_x, left_y in left_by_feature[shared_feature]:
            for right_x, right_y in right_by_feature[shared_feature]:
                candidates[(rounded(left_x - right_x), rounded(left_y - right_y))] += 1

    if not candidates:
        candidates[(0.0, 0.0)] = 1
    return candidates


def match_score(left_counts: Counter, right: list[dict], dx: float, dy: float) -> int:
    right_counts = Counter(entity_key(entity, dx, dy) for entity in right)
    return sum((left_counts & right_counts).values())


def best_translation(left: list[dict], right: list[dict]) -> tuple[float, float, int]:
    left_counts = Counter(entity_key(entity) for entity in left)
    candidates = candidate_translations(left, right)

    best = None
    for dx, dy in sorted(candidates):
        score = match_score(left_counts, right, dx, dy)
        candidate = (score, -abs(dx) - abs(dy), -abs(dx), -abs(dy), dx, dy)
        if best is None or candidate > best[0]:
            best = (candidate, dx, dy, score)

    assert best is not None
    return best[1], best[2], best[3]


def printable_key(key: tuple, origin_x: float, origin_y: float) -> str:
    name, direction, orientation, x, y = key
    orientation_text = "" if orientation is None else f", orientation={orientation:.6f}"
    return (
        f"{name} @ ({x - origin_x:.6f}, {y - origin_y:.6f}), "
        f"direction={direction}{orientation_text}"
    )


def compare(left: list[dict], right: list[dict]) -> int:
    dx, dy, matched = best_translation(left, right)
    left_counts = Counter(entity_key(entity) for entity in left)
    right_counts = Counter(entity_key(entity, dx, dy) for entity in right)

    missing = left_counts - right_counts
    extra = right_counts - left_counts

    all_positions = [(key[-2], key[-1]) for key in set(left_counts) | set(right_counts)]
    origin_x = min((x for x, _ in all_positions), default=0)
    origin_y = min((y for _, y in all_positions), default=0)

    print(f"Left entities:  {len(left)}")
    print(f"Right entities: {len(right)}")
    print(f"Best translation applied to right: dx={dx:.6f}, dy={dy:.6f}")
    print(f"Matched entities: {matched}")

    if not missing and not extra:
        print("Geometry matches after translation.")
        return 0

    print(f"Missing from right: {sum(missing.values())}")
    for key in sorted(missing, key=str):
        for _ in range(missing[key]):
            print("  - " + printable_key(key, origin_x, origin_y))

    print(f"Extra in right: {sum(extra.values())}")
    for key in sorted(extra, key=str):
        for _ in range(extra[key]):
            print("  + " + printable_key(key, origin_x, origin_y))

    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("left", help="Reference blueprint string, JSON, log, or file path")
    parser.add_argument("right", help="Blueprint string, JSON, log, or file path to compare")
    args = parser.parse_args()

    try:
        left_entities = extract_entities(load_payload(args.left))
        right_entities = extract_entities(load_payload(args.right))
    except (OSError, ValueError, json.JSONDecodeError, base64.binascii.Error, zlib.error) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    return compare(left_entities, right_entities)


if __name__ == "__main__":
    raise SystemExit(main())
