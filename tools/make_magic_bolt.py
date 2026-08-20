#!/usr/bin/env python3
"""Draw the staff projectile.

A staff cannot reach the enemy, so the bolt is what visibly crosses the lane.
It is drawn as a bright teardrop core with a dark rim and a short trailing tail
so its direction is readable while it travels.

Usage: python3 tools/make_magic_bolt.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 128
SS = 4
OUT = Path("assets/sprites/ui/magic_bolt.webp")


def main() -> None:
    image = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    cx = SIZE * SS * 0.5
    # tail first, so the head sits on top of it
    draw.polygon([(cx, SIZE * SS * 0.94), (cx - SIZE * SS * 0.11, SIZE * SS * 0.44),
                  (cx + SIZE * SS * 0.11, SIZE * SS * 0.44)], fill=(24, 18, 40, 220))
    draw.polygon([(cx, SIZE * SS * 0.90), (cx - SIZE * SS * 0.07, SIZE * SS * 0.46),
                  (cx + SIZE * SS * 0.07, SIZE * SS * 0.46)], fill=(255, 255, 255, 190))
    r = SIZE * SS * 0.21
    draw.ellipse((cx - r, SIZE * SS * 0.20, cx + r, SIZE * SS * 0.20 + r * 2), fill=(24, 18, 40, 240))
    r2 = r * 0.74
    draw.ellipse((cx - r2, SIZE * SS * 0.20 + (r - r2), cx + r2, SIZE * SS * 0.20 + r + r2),
                 fill=(198, 236, 255, 255))
    r3 = r * 0.38
    draw.ellipse((cx - r3, SIZE * SS * 0.20 + (r - r3), cx + r3, SIZE * SS * 0.20 + r + r3),
                 fill=(255, 255, 255, 255))
    image = image.resize((SIZE, SIZE), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.alpha_composite(image.filter(ImageFilter.GaussianBlur(4)))
    out.alpha_composite(image)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT, lossless=True)
    print(f"magic bolt {out.size[0]}x{out.size[1]} -> {OUT}")


if __name__ == "__main__":
    main()
