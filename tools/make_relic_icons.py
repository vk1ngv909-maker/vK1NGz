#!/usr/bin/env python3
"""Draw one icon per relic, in the approved cartoon language.

Fifteen permanent upgrades across five categories. Each icon has to say what its
relic does at inventory size, so the shapes are chosen per category -- force for
damage, coin for gold, wing for speed, glyph for skills, and a progression motif
for utility -- and differ within a category by silhouette, not only by colour.

Usage: python3 tools/make_relic_icons.py
"""
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 192
SS = 4
OUT = Path("assets/sprites/relics")
OUTLINE = (30, 24, 40, 255)
CATEGORY_TINT = {
    "damage": (232, 96, 84),
    "gold": (242, 190, 74),
    "speed": (108, 194, 232),
    "skills": (172, 126, 232),
    "utility": (118, 206, 156),
}


def shade(colour, amount: float):
    if amount < 0:
        return tuple([int(c * (1.0 + amount)) for c in colour] + [255])
    return tuple([int(c + (255 - c) * amount) for c in colour] + [255])


class Canvas:
    def __init__(self) -> None:
        self.image = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.image)

    def poly(self, points, fill, width: float = 5.0) -> None:
        self.draw.polygon([(x * SS, y * SS) for x, y in points], fill=fill, outline=OUTLINE, width=int(width * SS))

    def ellipse(self, box, fill, width: float = 5.0) -> None:
        self.draw.ellipse([v * SS for v in box], fill=fill, outline=OUTLINE, width=int(width * SS))

    def line(self, points, fill, width: float) -> None:
        self.draw.line([(x * SS, y * SS) for x, y in points], fill=fill, width=int(width * SS), joint="curve")

    def arc(self, box, start, end, fill, width: float) -> None:
        self.draw.arc([v * SS for v in box], start, end, fill=fill, width=int(width * SS))

    def result(self) -> Image.Image:
        return self.image.resize((SIZE, SIZE), Image.LANCZOS)


def stylize(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    w, h = image.size
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    light = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon([(w, 0), (w, h), (0, h)], fill=(16, 10, 26, 56))
    ImageDraw.Draw(light).ellipse([-w * 0.3, -h * 0.4, w * 0.7, h * 0.55], fill=(255, 255, 255, 40))
    shadow.putalpha(Image.composite(shadow.getchannel("A"), Image.new("L", image.size, 0), alpha))
    light.putalpha(Image.composite(light.getchannel("A"), Image.new("L", image.size, 0), alpha))
    out = image.copy()
    out.alpha_composite(shadow)
    out.alpha_composite(light)
    return out


# ---- damage: force, blade, impact ----------------------------------------
def sun_blade(c: Canvas, base, accent) -> None:
    c.poly([(96, 20), (118, 92), (110, 150), (96, 164), (82, 150), (74, 92)], shade(base, 0.2))
    c.poly([(96, 20), (96, 164), (82, 150), (74, 92)], shade(base, -0.15), 4)
    c.poly([(58, 150), (134, 150), (126, 166), (66, 166)], shade(accent, 0.0), 4)
    c.ellipse((86, 160, 106, 180), shade(accent, 0.2), 4)


def lion_seal(c: Canvas, base, accent) -> None:
    c.ellipse((28, 28, 164, 164), shade(base, 0.0))
    c.poly([(96, 52), (128, 84), (120, 132), (96, 148), (72, 132), (64, 84)], shade(accent, 0.1), 4)
    for x in (84, 108):
        c.ellipse((x - 8, 88, x + 8, 104), OUTLINE, 0)
    c.poly([(80, 118), (112, 118), (96, 136)], shade(base, -0.3), 4)


def storm_eye(c: Canvas, base, accent) -> None:
    c.poly([(96, 16), (140, 88), (108, 88), (150, 176), (56, 96), (90, 96), (52, 16)], shade(accent, 0.15))
    c.ellipse((70, 74, 122, 116), shade(base, 0.0), 5)
    c.ellipse((86, 86, 106, 106), OUTLINE, 0)


# ---- gold: coins, treasure, fortune ---------------------------------------
def merchant_scale(c: Canvas, base, accent) -> None:
    c.line([(96, 30), (96, 150)], OUTLINE, 7)
    c.line([(40, 58), (152, 58)], OUTLINE, 7)
    for x in (40, 152):
        c.arc((x - 26, 58, x + 26, 110), 0, 180, shade(base, 0.0), 8)
    c.poly([(72, 150), (120, 150), (130, 168), (62, 168)], shade(accent, 0.0), 4)


def gilded_scarab(c: Canvas, base, accent) -> None:
    c.ellipse((44, 44, 148, 156), shade(base, 0.0))
    c.ellipse((66, 32, 126, 78), shade(accent, 0.1), 4)
    c.line([(96, 60), (96, 150)], OUTLINE, 5)
    for side in (-1, 1):
        c.line([(96 + 30 * side, 70), (96 + 52 * side, 52)], OUTLINE, 5)
        c.line([(96 + 32 * side, 110), (96 + 56 * side, 110)], OUTLINE, 5)


def royal_coin(c: Canvas, base, accent) -> None:
    c.ellipse((26, 40, 130, 144), shade(base, -0.15))
    c.ellipse((56, 30, 166, 140), shade(base, 0.05))
    c.ellipse((74, 48, 148, 122), shade(accent, 0.2), 4)
    c.poly([(111, 60), (120, 80), (140, 84), (124, 98), (128, 118), (111, 108),
            (94, 118), (98, 98), (82, 84), (102, 80)], shade(base, -0.3), 3)


# ---- speed: wings, motion, falcon tempo ------------------------------------
def falcon_feather(c: Canvas, base, accent) -> None:
    c.poly([(120, 24), (150, 70), (120, 150), (74, 168), (58, 130), (72, 66)], shade(base, 0.05))
    c.line([(126, 36), (70, 156)], OUTLINE, 5)
    for offset in range(0, 5):
        c.line([(120 - offset * 12, 52 + offset * 22), (150 - offset * 14, 66 + offset * 20)], OUTLINE, 3)


def hourglass_shard(c: Canvas, base, accent) -> None:
    c.poly([(52, 24), (140, 24), (104, 96), (140, 168), (52, 168), (88, 96)], shade(base, 0.0))
    c.poly([(52, 24), (140, 24), (104, 96), (88, 96)], shade(accent, 0.15), 4)
    c.line([(44, 24), (148, 24)], OUTLINE, 7)
    c.line([(44, 168), (148, 168)], OUTLINE, 7)


def wildwind(c: Canvas, base, accent) -> None:
    for index, y in enumerate((58, 92, 126)):
        length = 132 - index * 18
        c.line([(28, y), (28 + length, y)], shade(base, 0.1 * index), 12)
        c.arc((28 + length - 26, y - 26, 28 + length + 26, y + 26), 270, 90, shade(accent, 0.1), 11)


# ---- skills: magic, cooldown, duration -------------------------------------
def ember_rune(c: Canvas, base, accent) -> None:
    c.poly([(96, 22), (156, 62), (156, 130), (96, 170), (36, 130), (36, 62)], shade(base, 0.0))
    c.line([(96, 56), (96, 136)], shade(accent, 0.3), 7)
    c.line([(70, 82), (122, 110)], shade(accent, 0.3), 7)
    c.line([(122, 82), (70, 110)], shade(accent, 0.3), 7)


def moon_dial(c: Canvas, base, accent) -> None:
    c.ellipse((28, 28, 164, 164), shade(base, 0.0))
    c.ellipse((56, 16, 176, 136), (0, 0, 0, 0), 0)
    c.arc((44, 44, 148, 148), 120, 400, shade(accent, 0.25), 9)
    c.line([(96, 96), (96, 54)], OUTLINE, 6)
    c.line([(96, 96), (130, 116)], OUTLINE, 6)


def spirit_lantern(c: Canvas, base, accent) -> None:
    c.line([(72, 26), (96, 46), (120, 26)], OUTLINE, 6)
    c.poly([(66, 46), (126, 46), (140, 92), (126, 158), (66, 158), (52, 92)], shade(base, 0.0))
    c.ellipse((76, 74, 116, 126), shade(accent, 0.3), 4)
    c.line([(60, 158), (132, 158)], OUTLINE, 7)


# ---- utility: offline reward, efficiency, progression ----------------------
def grove_charm(c: Canvas, base, accent) -> None:
    c.line([(96, 22), (96, 60)], OUTLINE, 6)
    c.ellipse((44, 60, 148, 164), shade(base, 0.0))
    c.poly([(96, 78), (124, 106), (96, 146), (68, 106)], shade(accent, 0.2), 4)
    c.line([(96, 84), (96, 142)], OUTLINE, 4)


def map_of_stars(c: Canvas, base, accent) -> None:
    c.poly([(30, 44), (96, 28), (162, 44), (162, 154), (96, 168), (30, 154)], shade(base, 0.0))
    c.line([(96, 28), (96, 168)], OUTLINE, 4)
    for cx, cy in ((60, 76), (120, 62), (140, 120), (72, 130)):
        c.poly([(cx, cy - 12), (cx + 6, cy - 4), (cx + 14, cy), (cx + 6, cy + 6),
                (cx, cy + 14), (cx - 6, cy + 6), (cx - 14, cy), (cx - 6, cy - 4)],
               shade(accent, 0.3), 3)


def phoenix_sigil(c: Canvas, base, accent) -> None:
    c.poly([(96, 20), (140, 66), (116, 74), (150, 132), (96, 116), (42, 132),
            (76, 74), (52, 66)], shade(base, 0.0))
    c.poly([(96, 20), (96, 116), (42, 132), (76, 74), (52, 66)], shade(base, -0.2), 4)
    c.ellipse((80, 128, 112, 164), shade(accent, 0.25), 4)


DRAWERS = {
    "sun_blade": sun_blade, "lion_seal": lion_seal, "storm_eye": storm_eye,
    "merchant_scale": merchant_scale, "gilded_scarab": gilded_scarab, "sultans_coin": royal_coin,
    "falcon_feather": falcon_feather, "hourglass_shard": hourglass_shard, "desert_wind": wildwind,
    "ember_rune": ember_rune, "moon_dial": moon_dial, "djinn_lamp": spirit_lantern,
    "oasis_charm": grove_charm, "map_of_stars": map_of_stars, "phoenix_ankh": phoenix_sigil,
}


def main() -> None:
    data = json.loads(Path("resources/relics/relics.json").read_text())
    key = next(k for k, v in data.items() if isinstance(v, list))
    OUT.mkdir(parents=True, exist_ok=True)
    drawn = 0
    for entry in data[key]:
        relic_id = entry["id"]
        drawer = DRAWERS.get(relic_id)
        assert drawer is not None, f"no icon drawn for relic '{relic_id}'"
        tint = CATEGORY_TINT[entry["category"]]
        canvas = Canvas()
        drawer(canvas, tint, shade(tint, 0.45)[:3])
        image = stylize(canvas.result())
        target = OUT / f"{relic_id}.webp"
        image.save(target, "WEBP", lossless=True)
        drawn += 1
        print(f"{relic_id:18s} {entry['category']:8s} -> {target}")
    assert drawn == len(data[key]) == 15, f"expected 15 relic icons, drew {drawn}"
    print(f"\n{drawn} relic icons at {SIZE}x{SIZE}")


if __name__ == "__main__":
    main()
