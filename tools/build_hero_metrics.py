#!/usr/bin/env python3
"""Bake the hero sprites' alpha bounds.

The two hero PNGs are 2048x2048 with the character sitting inside transparent
padding, and the idle and attack poses do not fill the canvas identically. The
runtime places and scales the hero from these bounds, so the *visible* body
lands on the same ground line in both poses instead of the canvas doing it.

Measured rather than eyeballed, and re-measured by
tests/unit/test_hero_assets.gd, which fails if this file and the PNGs disagree.

Usage: python3 tools/build_hero_metrics.py
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

SPRITES = {
    "idle": "assets/sprites/hero/hero_rear_idle_v3_2048.png",
    "attack": "assets/sprites/hero/hero_rear_attack_v3_2048.png",
}
ALPHA_THRESHOLD = 16
OUT = Path("resources/hero_sprite_metrics.json")


def main() -> None:
    data: dict = {"schema_version": 1, "alpha_threshold": ALPHA_THRESHOLD, "sprites": {}}
    for key, path in SPRITES.items():
        image = Image.open(path).convert("RGBA")
        alpha = np.array(image.getchannel("A"))
        rows, columns = np.nonzero(alpha > ALPHA_THRESHOLD)
        data["sprites"][key] = {
            "path": f"res://{path}",
            "canvas": [image.width, image.height],
            "bbox": [int(columns.min()), int(rows.min()), int(columns.max()) + 1, int(rows.max()) + 1],
            "sha256": hashlib.sha256(Path(path).read_bytes()).hexdigest(),
        }
    OUT.write_text(json.dumps(data, indent=1) + "\n")
    for key, entry in data["sprites"].items():
        print(f"{key}: canvas {entry['canvas'][0]}x{entry['canvas'][1]} bbox {entry['bbox']}")


if __name__ == "__main__":
    main()
