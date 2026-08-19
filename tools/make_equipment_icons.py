#!/usr/bin/env python3
"""Draw original cartoon icons for the equipment slots the concept package
does not cover, and frame every equipment icon by rarity.

The package ships weapon-type art only, so head, outfit and companion_charm
items had no honest icon. These are drawn here from scratch in the same
language as the rest of the art: bold dark outline, flat colour, one shade
step and one highlight. Rarity is carried by the frame and the badge pips as
well as by colour, so it survives a colour-blind read and a small screen.

Usage: python3 tools/make_equipment_icons.py
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 256
SS = 4                      # supersample factor
PAD = 0.12                  # safe padding required on every side
OUT = Path("assets/sprites/equipment")
CLEANED = Path("assets/sprites/equipment")

OUTLINE = (34, 26, 44, 255)
RARITY = {
    "common": (176, 184, 198),
    "rare": (86, 156, 236),
    "epic": (186, 108, 232),
    "legendary": (246, 170, 58),
}
PIPS = {"common": 1, "rare": 2, "epic": 3, "legendary": 4}


def shade(colour: tuple[int, int, int], amount: float) -> tuple[int, int, int, int]:
    if amount < 0:
        return tuple([int(c * (1.0 + amount)) for c in colour] + [255])
    return tuple([int(c + (255 - c) * amount) for c in colour] + [255])


class Canvas:
    """Draws in supersampled space with a consistent cartoon outline."""

    def __init__(self) -> None:
        self.image = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.image)

    def poly(self, points: list[tuple[float, float]], fill, width: float = 7.0) -> None:
        scaled = [(x * SS, y * SS) for x, y in points]
        self.draw.polygon(scaled, fill=fill, outline=OUTLINE, width=int(width * SS))

    def ellipse(self, box: tuple[float, float, float, float], fill, width: float = 7.0) -> None:
        scaled = [v * SS for v in box]
        self.draw.ellipse(scaled, fill=fill, outline=OUTLINE, width=int(width * SS))

    def arc_band(self, box, start, end, fill, width: float) -> None:
        scaled = [v * SS for v in box]
        self.draw.arc(scaled, start, end, fill=fill, width=int(width * SS))

    def line(self, points, fill, width: float) -> None:
        scaled = [(x * SS, y * SS) for x, y in points]
        self.draw.line(scaled, fill=fill, width=int(width * SS), joint="curve")

    def result(self) -> Image.Image:
        return self.image.resize((SIZE, SIZE), Image.LANCZOS)


def hood(c: Canvas, base, accent) -> None:
    c.poly([(72, 176), (78, 108), (110, 74), (146, 74), (178, 108), (184, 176),
            (156, 168), (128, 182), (100, 168)], shade(base, 0.0))
    c.poly([(128, 182), (100, 168), (110, 120), (128, 104)], shade(base, -0.22), 5)
    c.poly([(104, 118), (128, 96), (152, 118), (128, 138)], shade(accent, 0.0), 5)
    c.line([(92, 150), (128, 162), (164, 150)], OUTLINE, 5)


def circlet(c: Canvas, base, accent) -> None:
    c.arc_band((66, 92, 190, 200), 200, 340, OUTLINE, 20)
    c.arc_band((66, 92, 190, 200), 200, 340, shade(base, 0.0), 12)
    for x, y, s in [(96, 112, 16), (128, 100, 20), (160, 112, 16)]:
        c.poly([(x, y - s), (x + s * 0.7, y), (x, y + s), (x - s * 0.7, y)], shade(accent, 0.0), 5)
    c.poly([(112, 150), (128, 132), (144, 150), (128, 166)], shade(accent, 0.25), 5)


def veil(c: Canvas, base, accent) -> None:
    c.poly([(84, 96), (128, 70), (172, 96), (178, 182), (150, 170), (128, 186),
            (106, 170), (78, 182)], shade(base, 0.0))
    c.poly([(128, 186), (106, 170), (78, 182), (84, 96), (128, 70)], shade(base, -0.2), 5)
    # A dark face opening is what separates a veil from a plain cloak.
    c.ellipse((104, 96, 152, 150), (26, 20, 34, 255), 5)
    c.poly([(118, 82), (128, 66), (138, 82), (128, 96)], shade(accent, 0.15), 4)
    c.line([(96, 156), (128, 168), (160, 156)], shade(accent, -0.1), 5)


def crown(c: Canvas, base, accent) -> None:
    c.poly([(70, 178), (78, 92), (104, 130), (128, 78), (152, 130), (178, 92), (186, 178)],
           shade(base, 0.0))
    c.poly([(70, 178), (78, 92), (104, 130), (128, 78), (128, 178)], shade(base, -0.18), 5)
    for x, y in [(78, 86), (128, 70), (178, 86)]:
        c.poly([(x, y - 14), (x + 9, y), (x, y + 14), (x - 9, y)], shade(accent, 0.15), 4)
    c.ellipse((116, 140, 140, 164), shade(accent, 0.0), 5)


def cloak(c: Canvas, base, accent) -> None:
    c.poly([(128, 66), (170, 92), (188, 190), (128, 176), (68, 190), (86, 92)],
           shade(base, 0.0))
    c.poly([(128, 66), (128, 176), (68, 190), (86, 92)], shade(base, -0.2), 5)
    c.ellipse((114, 74, 142, 100), shade(accent, 0.1), 5)
    c.line([(104, 120), (128, 132), (152, 120)], OUTLINE, 5)


def mail(c: Canvas, base, accent) -> None:
    c.poly([(88, 78), (128, 92), (168, 78), (184, 116), (170, 186), (128, 196),
            (86, 186), (72, 116)], shade(base, 0.0))
    c.poly([(128, 92), (128, 196), (86, 186), (72, 116), (88, 78)], shade(base, -0.2), 5)
    for y in (124, 150):
        c.line([(94, y), (162, y)], OUTLINE, 5)
    c.ellipse((114, 100, 142, 128), shade(accent, 0.1), 5)


def mantle(c: Canvas, base, accent) -> None:
    c.poly([(128, 68), (176, 96), (186, 188), (128, 170), (70, 188), (80, 96)],
           shade(base, 0.0))
    c.poly([(128, 68), (128, 170), (70, 188), (80, 96)], shade(base, -0.22), 5)
    c.poly([(136, 96), (112, 134), (130, 134), (114, 172), (152, 124), (132, 124)],
           shade(accent, 0.2), 5)


def regalia(c: Canvas, base, accent) -> None:
    c.poly([(128, 62), (172, 88), (188, 192), (128, 176), (68, 192), (84, 88)],
           shade(base, 0.0))
    c.poly([(128, 62), (128, 176), (68, 192), (84, 88)], shade(base, -0.2), 5)
    c.poly([(108, 92), (128, 74), (148, 92), (128, 112)], shade(accent, 0.2), 5)
    for y in (132, 156):
        c.poly([(118, y), (128, y - 10), (138, y), (128, y + 10)], shade(accent, 0.0), 4)


def token(c: Canvas, base, accent) -> None:
    c.ellipse((72, 72, 184, 184), shade(base, 0.0))
    c.ellipse((88, 88, 168, 168), shade(base, -0.16), 5)
    # A readable beetle, not an abstract disc: body, wing split, head and legs.
    for side in (-1, 1):
        c.line([(128 + 22 * side, 118), (128 + 40 * side, 104)], OUTLINE, 4)
        c.line([(128 + 24 * side, 132), (128 + 44 * side, 132)], OUTLINE, 4)
        c.line([(128 + 22 * side, 146), (128 + 40 * side, 160)], OUTLINE, 4)
    c.ellipse((108, 106, 148, 162), shade(accent, 0.05), 5)
    c.ellipse((116, 92, 140, 112), shade(accent, -0.15), 4)
    c.line([(128, 110), (128, 158)], OUTLINE, 4)


def bell(c: Canvas, base, accent) -> None:
    # Wide skirt, a distinct rim band and a visible clapper: a narrow wedge
    # read as a tent rather than a bell at icon size.
    c.poly([(128, 62), (146, 76), (158, 118), (176, 158), (80, 158), (98, 118), (110, 76)],
           shade(base, 0.0))
    c.poly([(128, 62), (128, 158), (80, 158), (98, 118), (110, 76)], shade(base, -0.2), 5)
    c.ellipse((78, 148, 178, 176), shade(base, 0.12), 6)
    c.ellipse((116, 174, 140, 198), shade(accent, -0.05), 5)
    c.ellipse((118, 52, 138, 70), shade(accent, 0.1), 5)


def talisman(c: Canvas, base, accent) -> None:
    c.line([(94, 62), (128, 96), (162, 62)], OUTLINE, 6)
    c.ellipse((80, 88, 176, 184), shade(base, 0.0))
    # Crescent moon plus a fox ear and muzzle, so the name is legible at icon
    # size instead of an abstract swirl.
    c.ellipse((98, 106, 158, 166), shade(accent, 0.25), 5)
    c.ellipse((114, 100, 174, 160), shade(base, 0.0), 0)
    c.poly([(112, 148), (124, 118), (140, 146)], shade(accent, 0.1), 4)
    c.poly([(118, 150), (138, 150), (128, 166)], shade(accent, -0.1), 4)


def signet(c: Canvas, base, accent) -> None:
    c.ellipse((76, 96, 180, 200), shade(base, 0.0))
    c.ellipse((104, 124, 152, 172), (0, 0, 0, 0), 6)
    c.poly([(128, 52), (156, 92), (128, 118), (100, 92)], shade(base, 0.1), 6)
    c.poly([(128, 66), (144, 92), (128, 108), (112, 92)], shade(accent, 0.2), 4)


ITEMS = {
    # head
    "wanderer_wrap": (hood, "common", (188, 168, 140), (120, 150, 120)),
    "scarab_circlet": (circlet, "rare", (214, 196, 120), (120, 196, 130)),
    "oracle_veil": (veil, "epic", (168, 142, 216), (240, 226, 160)),
    "crown_of_stars": (crown, "legendary", (242, 198, 92), (128, 208, 244)),
    # outfit
    "traveler_robes": (cloak, "common", (150, 168, 190), (196, 170, 128)),
    "caravan_guard_mail": (mail, "rare", (162, 178, 196), (98, 176, 232)),
    "stormweave_mantle": (mantle, "epic", (120, 118, 200), (250, 226, 120)),
    "sultans_regalia": (regalia, "legendary", (214, 150, 92), (248, 214, 128)),
    # companion_charm
    "beetle_token": (token, "common", (186, 172, 148), (140, 168, 128)),
    "falcon_bell": (bell, "rare", (222, 196, 118), (250, 240, 200)),
    "moon_fox_talisman": (talisman, "epic", (156, 132, 214), (246, 240, 206)),
    "phoenix_signet": (signet, "legendary", (238, 178, 84), (250, 108, 72)),
}


def frame(image: Image.Image, rarity: str) -> Image.Image:
    """Rarity frame and badge, drawn on top of any icon.

    Colour alone is not enough on a phone, so the corner brackets thicken with
    rarity and the badge shows one pip per tier.
    """
    layer = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    colour = RARITY[rarity] + (255,)
    pips = PIPS[rarity]
    thickness = (3 + pips) * SS
    inset = int(SIZE * PAD * 0.5) * SS
    arm = int(SIZE * 0.20) * SS
    right = SIZE * SS - inset
    bottom = SIZE * SS - inset
    for x, y, dx, dy in [(inset, inset, 1, 1), (right, inset, -1, 1),
                         (inset, bottom, 1, -1), (right, bottom, -1, -1)]:
        draw.line([(x, y), (x + arm * dx, y)], fill=colour, width=thickness)
        draw.line([(x, y), (x, y + arm * dy)], fill=colour, width=thickness)
    plate_w = int(SIZE * 0.10) * SS * pips
    plate_h = int(SIZE * 0.07) * SS
    cx = SIZE * SS // 2
    plate = [cx - plate_w // 2, bottom - plate_h, cx + plate_w // 2, bottom]
    draw.rounded_rectangle(plate, radius=plate_h // 2, fill=(24, 20, 30, 235), outline=colour, width=2 * SS)
    step = plate_w / pips
    for index in range(pips):
        px = plate[0] + step * (index + 0.5)
        py = (plate[1] + plate[3]) / 2
        r = plate_h * 0.26
        draw.ellipse([px - r, py - r, px + r, py + r], fill=colour)
    small = layer.resize((SIZE, SIZE), Image.LANCZOS)
    out = image.copy()
    out.alpha_composite(small)
    return out


def stylize(image: Image.Image) -> Image.Image:
    """One shade step and one highlight, applied through the art's own mask.

    Drawing each icon's shading by hand drifts between items; deriving it from
    the silhouette keeps all twelve in the same visual language as the painted
    package icons they sit beside.
    """
    alpha = image.getchannel("A")
    width, height = image.size
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    light = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon(
        [(width, 0), (width, height), (0, height)], fill=(20, 14, 30, 64))
    ImageDraw.Draw(light).ellipse(
        [-width * 0.35, -height * 0.45, width * 0.72, height * 0.55], fill=(255, 255, 255, 42))
    shadow.putalpha(Image.composite(shadow.getchannel("A"), Image.new("L", image.size, 0), alpha))
    light.putalpha(Image.composite(light.getchannel("A"), Image.new("L", image.size, 0), alpha))
    out = image.copy()
    out.alpha_composite(shadow)
    out.alpha_composite(light)
    return out


def fit_with_padding(image: Image.Image) -> Image.Image:
    """Scale the drawn art so nothing enters the 12% safe margin."""
    box = image.getbbox()
    if box is None:
        return image
    inner = int(SIZE * (1.0 - PAD * 2))
    art = image.crop(box)
    scale = min(inner / art.width, inner / art.height)
    art = art.resize((max(1, int(art.width * scale)), max(1, int(art.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(art, ((SIZE - art.width) // 2, (SIZE - art.height) // 2))
    return canvas


def main() -> None:
    data = json.loads(Path("resources/equipment/equipment.json").read_text())
    key = next(k for k, v in data.items() if isinstance(v, list))
    rarities = {entry["id"]: entry["rarity"] for entry in data[key]}
    OUT.mkdir(parents=True, exist_ok=True)

    report = {}
    for item_id, (drawer, rarity, base, accent) in ITEMS.items():
        assert rarities[item_id] == rarity, f"{item_id} rarity drifted"
        canvas = Canvas()
        drawer(canvas, base, accent)
        image = fit_with_padding(stylize(canvas.result()))
        image = frame(image, rarity)
        target = OUT / f"{item_id}.webp"
        image.save(target, "WEBP", lossless=True)
        report[item_id] = str(target)
        print(f"drew   {item_id:22s} {rarity:10s} -> {target}")

    # The eight cleaned package icons get the same frame and badge so all
    # twenty read as one set.
    for png in sorted(CLEANED.glob("*.png")):
        item_id = png.stem
        rarity = rarities.get(item_id)
        if rarity is None:
            continue
        image = fit_with_padding(Image.open(png).convert("RGBA"))
        image = frame(image, rarity)
        target = OUT / f"{item_id}.webp"
        image.save(target, "WEBP", lossless=True)
        png.unlink()
        Path(str(png) + ".import").unlink(missing_ok=True)
        report[item_id] = str(target)
        print(f"framed {item_id:22s} {rarity:10s} -> {target}")

    print(f"\n{len(report)} equipment icons at {SIZE}x{SIZE}")


if __name__ == "__main__":
    main()
