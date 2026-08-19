#!/usr/bin/env python3
"""Draw the UI icons the game needs: the gold coin and one per skill.

Same cartoon language as the equipment icons -- bold outline, flat colour, one
shade step, one highlight -- so the HUD does not read as a different game from
the actors. Each skill icon carries a distinct silhouette, because the skill row
must be readable at a glance and colour alone is not enough.

Usage: python3 tools/make_ui_icons.py
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 192
SS = 4
OUT = Path("assets/sprites/ui")
OUTLINE = (32, 24, 42, 255)


def shade(colour, amount: float):
    if amount < 0:
        return tuple([int(c * (1.0 + amount)) for c in colour] + [255])
    return tuple([int(c + (255 - c) * amount) for c in colour] + [255])


class Canvas:
    def __init__(self) -> None:
        self.image = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.image)

    def poly(self, points, fill, width: float = 5.0) -> None:
        self.draw.polygon([(x * SS, y * SS) for x, y in points], fill=fill,
                          outline=OUTLINE, width=int(width * SS))

    def ellipse(self, box, fill, width: float = 5.0) -> None:
        self.draw.ellipse([v * SS for v in box], fill=fill, outline=OUTLINE,
                          width=int(width * SS))

    def line(self, points, fill, width: float) -> None:
        self.draw.line([(x * SS, y * SS) for x, y in points], fill=fill,
                       width=int(width * SS), joint="curve")

    def arc(self, box, start, end, fill, width: float) -> None:
        self.draw.arc([v * SS for v in box], start, end, fill=fill, width=int(width * SS))

    def result(self) -> Image.Image:
        return self.image.resize((SIZE, SIZE), Image.LANCZOS)


def stylize(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    w, h = image.size
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    light = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon([(w, 0), (w, h), (0, h)], fill=(18, 12, 28, 58))
    ImageDraw.Draw(light).ellipse([-w * 0.3, -h * 0.4, w * 0.72, h * 0.55], fill=(255, 255, 255, 40))
    shadow.putalpha(Image.composite(shadow.getchannel("A"), Image.new("L", image.size, 0), alpha))
    light.putalpha(Image.composite(light.getchannel("A"), Image.new("L", image.size, 0), alpha))
    out = image.copy()
    out.alpha_composite(shadow)
    out.alpha_composite(light)
    return out


def coin(c: Canvas) -> None:
    gold = (246, 196, 70)
    c.ellipse((22, 22, 170, 170), shade(gold, 0.0), 6)
    c.ellipse((40, 40, 152, 152), shade(gold, 0.16), 5)
    c.poly([(96, 58), (112, 88), (144, 92), (120, 116), (128, 148),
            (96, 132), (64, 148), (72, 116), (48, 92), (80, 88)], shade(gold, -0.28), 4)


def sand_fury(c: Canvas) -> None:
    # A fist: raw tap damage.
    base = (226, 138, 72)
    c.poly([(52, 108), (60, 74), (86, 62), (128, 62), (146, 78), (146, 132),
            (120, 150), (70, 148)], shade(base, 0.0))
    for x in (86, 106, 126):
        c.line([(x, 74), (x, 104)], OUTLINE, 4)
    c.poly([(44, 96), (62, 88), (66, 122), (46, 126)], shade(base, -0.2), 4)


def falcon_storm(c: Canvas) -> None:
    # A diving bird: the falcon's rate.
    base = (118, 202, 236)
    c.poly([(96, 40), (150, 78), (120, 92), (156, 132), (96, 152), (36, 132),
            (72, 92), (42, 78)], shade(base, 0.0))
    c.poly([(96, 40), (96, 152), (36, 132), (72, 92), (42, 78)], shade(base, -0.22), 4)
    c.ellipse((86, 62, 106, 82), shade(base, 0.35), 4)


def golden_wind(c: Canvas) -> None:
    # Coins caught in a gust.
    gold = (246, 200, 78)
    for cx, cy, r in [(70, 118, 30), (116, 96, 26), (138, 134, 20)]:
        c.ellipse((cx - r, cy - r, cx + r, cy + r), shade(gold, 0.0), 5)
    for y in (58, 74):
        c.arc((30, y - 18, 150, y + 26), 200, 340, shade(gold, 0.3), 6)


def time_fracture(c: Canvas) -> None:
    # A cracked clock face: the boss timer.
    base = (156, 214, 214)
    c.ellipse((30, 30, 162, 162), shade(base, 0.0), 6)
    c.line([(96, 96), (96, 56)], OUTLINE, 6)
    c.line([(96, 96), (128, 116)], OUTLINE, 6)
    c.line([(60, 40), (86, 84), (54, 104), (96, 158)], shade(base, -0.45), 5)


def ancestor_call(c: Canvas) -> None:
    # Three rising spirits: the support roster.
    base = (186, 158, 238)
    for cx, top, scale in [(58, 92, 0.8), (96, 58, 1.0), (134, 92, 0.8)]:
        h = 62 * scale
        c.poly([(cx, top), (cx + 20 * scale, top + h * 0.5), (cx + 14 * scale, top + h),
                (cx - 14 * scale, top + h), (cx - 20 * scale, top + h * 0.5)],
               shade(base, 0.0 if scale == 1.0 else -0.18), 4)
        c.ellipse((cx - 9 * scale, top + h * 0.22, cx + 9 * scale, top + h * 0.6),
                  shade(base, 0.35), 3)


def critical_eclipse(c: Canvas) -> None:
    # An eclipsed disc with a crit spark.
    base = (238, 122, 96)
    c.ellipse((28, 28, 164, 164), shade(base, 0.0), 6)
    c.ellipse((52, 20, 172, 140), (26, 20, 34, 255), 5)
    c.poly([(120, 106), (150, 118), (126, 130), (146, 158), (112, 140), (98, 164),
            (100, 132), (76, 122)], shade(base, 0.4), 4)


ICONS = {
    "coin": coin,
    "skill_sand_fury": sand_fury,
    "skill_falcon_storm": falcon_storm,
    "skill_golden_wind": golden_wind,
    "skill_time_fracture": time_fracture,
    "skill_ancestor_call": ancestor_call,
    "skill_critical_eclipse": critical_eclipse,
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, drawer in ICONS.items():
        canvas = Canvas()
        drawer(canvas)
        image = stylize(canvas.result())
        target = OUT / f"{name}.webp"
        image.save(target, "WEBP", lossless=True)
        print(f"{name:24s} -> {target}")
    print(f"\n{len(ICONS)} UI icons at {SIZE}x{SIZE}")


if __name__ == "__main__":
    main()
