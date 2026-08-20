#!/usr/bin/env python3
"""Draw the sword slash arc.

The first arc was a thin pale crescent and disappeared against the bright
meadow background, so the hit never visibly connected. This draws a tapered
crescent with a dark rim and a white hot core, which stays readable over both
the light meadow and the dark citadel.

Usage: python3 tools/make_slash_arc.py
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 256
SS = 4
OUT = Path("assets/sprites/ui/slash_arc.webp")


def crescent(draw: ImageDraw.ImageDraw, radius: float, thickness: float, colour) -> None:
    """A stroke that swells in the middle and tapers to points at both ends."""
    centre = SIZE * SS * 0.5
    base_y = SIZE * SS * 0.86
    steps = 220
    for index in range(steps):
        t = index / (steps - 1)
        angle = math.pi * (1.0 - t)
        taper = math.sin(math.pi * t) ** 0.55
        width = thickness * taper
        if width < 1.0:
            continue
        x = centre + math.cos(angle) * radius
        y = base_y - math.sin(angle) * radius
        draw.ellipse((x - width, y - width, x + width, y + width), fill=colour)


def main() -> None:
    image = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    radius = SIZE * SS * 0.40
    crescent(draw, radius, SIZE * SS * 0.085, (26, 18, 34, 235))
    crescent(draw, radius, SIZE * SS * 0.062, (255, 214, 120, 255))
    crescent(draw, radius * 1.004, SIZE * SS * 0.030, (255, 253, 244, 255))
    image = image.resize((SIZE, SIZE), Image.LANCZOS)
    glow = image.filter(ImageFilter.GaussianBlur(5))
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(image)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT, lossless=True)
    print(f"slash arc {out.size[0]}x{out.size[1]} -> {OUT}")


if __name__ == "__main__":
    main()
