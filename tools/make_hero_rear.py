#!/usr/bin/env python3
"""Draw the rear-view main hero.

The approved combat direction puts the camera behind the player, so the front
facing hero from the concept package cannot be used. This draws a rear
three-quarter hero in the same cartoon language: brown hair from behind, a teal
cloak, readable arms and legs, and a sword held ready. The back panel of the
cloak is kept as one clean shape so a costume can be swapped onto it later.

Usage: python3 tools/make_hero_rear.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

W, H = 320, 420
SS = 4
OUT = Path("assets/sprites/hero")
OUTLINE = (28, 22, 38, 255)

SKIN = (232, 186, 148)
HAIR = (108, 72, 44)
CLOAK = (38, 148, 148)
CLOAK_DARK = (24, 110, 112)
TUNIC = (232, 226, 212)
BELT = (128, 84, 48)
BOOT = (92, 62, 40)
STEEL = (206, 214, 226)
GRIP = (120, 78, 46)


def shade(colour, amount: float):
    if amount < 0:
        return tuple([int(c * (1.0 + amount)) for c in colour] + [255])
    return tuple([int(c + (255 - c) * amount) for c in colour] + [255])


class Canvas:
    def __init__(self) -> None:
        self.image = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.image)

    def poly(self, points, fill, width: float = 6.0) -> None:
        self.draw.polygon([(x * SS, y * SS) for x, y in points], fill=fill, outline=OUTLINE, width=int(width * SS))

    def ellipse(self, box, fill, width: float = 6.0) -> None:
        self.draw.ellipse([v * SS for v in box], fill=fill, outline=OUTLINE, width=int(width * SS))

    def line(self, points, fill, width: float) -> None:
        self.draw.line([(x * SS, y * SS) for x, y in points], fill=fill, width=int(width * SS), joint="curve")

    def result(self) -> Image.Image:
        return self.image.resize((W, H), Image.LANCZOS)


def draw_hero(c: Canvas) -> None:
    # legs and boots, planted and symmetric so the anchor never drifts
    for side in (-1, 1):
        x = 160 + 30 * side
        c.poly([(x - 20, 300), (x + 20, 300), (x + 17, 372), (x - 17, 372)], shade(TUNIC, -0.42))
        c.poly([(x - 22, 366), (x + 22, 366), (x + 25, 396), (x - 25, 396)], shade(BOOT, 0.0))

    # cloak: one clean back panel, the part a costume would replace
    c.poly([(160, 120), (238, 168), (252, 330), (160, 352), (68, 330), (82, 168)], shade(CLOAK, 0.0))
    c.poly([(160, 120), (160, 352), (68, 330), (82, 168)], shade(CLOAK_DARK, 0.0), 5)
    c.line([(160, 150), (160, 344)], shade(CLOAK_DARK, -0.25), 4)

    # shoulders and arms, read from behind
    c.poly([(96, 176), (128, 156), (192, 156), (224, 176), (214, 214), (106, 214)], shade(TUNIC, -0.28))
    for side in (-1, 1):
        x = 160 + 74 * side
        c.poly([(x - 16, 176), (x + 16, 176), (x + 13, 258), (x - 13, 258)], shade(TUNIC, -0.2), 5)
        c.ellipse((x - 17, 250, x + 17, 284), shade(SKIN, -0.1), 5)

    # belt
    c.poly([(112, 268), (208, 268), (208, 296), (112, 296)], shade(BELT, 0.0), 5)
    c.ellipse((146, 268, 174, 296), shade(BELT, 0.35), 4)

    # head from behind: hair mass, no face
    c.ellipse((116, 44, 204, 140), shade(SKIN, -0.05))
    c.poly([(112, 96), (118, 52), (146, 30), (174, 30), (202, 52), (208, 96),
            (196, 128), (180, 104), (160, 118), (140, 104), (124, 128)], shade(HAIR, 0.0))
    c.poly([(112, 96), (118, 52), (146, 30), (160, 30), (160, 118), (140, 104), (124, 128)],
           shade(HAIR, -0.2), 5)

    # sword held out to the hero's right, angled toward the enemy ahead. The
    # grip, guard and blade share one axis so the weapon reads as one object.
    c.line([(236, 272), (274, 202)], shade(GRIP, 0.0), 14)
    c.ellipse((266, 190, 288, 212), shade(STEEL, -0.3), 4)
    # crossguard sits across the blade axis, at the point the blade begins
    c.poly([(252, 178), (296, 154), (306, 172), (262, 196)], shade(STEEL, -0.25), 5)
    c.poly([(258, 176), (300, 152), (292, 40), (250, 152)], shade(STEEL, 0.15))
    c.poly([(272, 168), (292, 40), (250, 152)], shade(STEEL, -0.18), 4)


def stylize(image: Image.Image) -> Image.Image:
    """One shade step and one highlight, taken from the silhouette, so the hero
    sits in the same cel-shaded language as the rest of the cast."""
    alpha = image.getchannel("A")
    width, height = image.size
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    light = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon([(width, 0), (width, height), (0, height)], fill=(18, 12, 28, 52))
    ImageDraw.Draw(light).ellipse([-width * 0.3, -height * 0.35, width * 0.68, height * 0.5], fill=(255, 255, 255, 34))
    shadow.putalpha(Image.composite(shadow.getchannel("A"), Image.new("L", image.size, 0), alpha))
    light.putalpha(Image.composite(light.getchannel("A"), Image.new("L", image.size, 0), alpha))
    out = image.copy()
    out.alpha_composite(shadow)
    out.alpha_composite(light)
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    canvas = Canvas()
    draw_hero(canvas)
    image = stylize(canvas.result())
    box = image.getbbox()
    if box is not None:
        image = image.crop(box)
        padded = Image.new("RGBA", (image.width + 8, image.height + 8), (0, 0, 0, 0))
        padded.alpha_composite(image, (4, 4))
        image = padded
    target = OUT / "main_hero_rear.png"
    image.save(target)
    print(f"rear-view hero {image.size[0]}x{image.size[1]} -> {target}")


if __name__ == "__main__":
    main()
