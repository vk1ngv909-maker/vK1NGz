#!/usr/bin/env python3
"""One labelled contact sheet proving every equipment icon exists.

Grouped by the five real slots, four rarities across, with id, slot and rarity
printed under each icon so the sheet can be audited without opening the game.

Usage: python3 tools/build_equipment_sheet.py
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ICONS = Path("assets/sprites/equipment")
TARGET = Path("docs/evidence/equipment_contact_sheet.webp")
CELL = 300
LABEL = 92
HEADER = 76
ROW_TITLE = 52
BG = (17, 16, 23)
CARD = (28, 26, 36)
INK = (240, 238, 246)
DIM = (156, 152, 168)
RARITY = {
    "common": (176, 184, 198),
    "rare": (86, 156, 236),
    "epic": (186, 108, 232),
    "legendary": (246, 170, 58),
}
ORDER = ["common", "rare", "epic", "legendary"]
SLOTS = ["weapon", "head", "outfit", "aura", "companion_charm"]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    path = Path("/usr/share/fonts/truetype/dejavu") / name
    return ImageFont.truetype(str(path), size) if path.exists() else ImageFont.load_default()


def main() -> None:
    data = json.loads(Path("resources/equipment/equipment.json").read_text())
    key = next(k for k, v in data.items() if isinstance(v, list))
    by_slot: dict[str, dict[str, str]] = {slot: {} for slot in SLOTS}
    for entry in data[key]:
        by_slot[entry["slot"]][entry["rarity"]] = entry["id"]

    width = 40 + 4 * (CELL + 20)
    height = HEADER + len(SLOTS) * (ROW_TITLE + CELL + LABEL + 18) + 24
    sheet = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(sheet)
    draw.text((28, 22), "Equipment icons - 20 of 20, five slots, four rarities",
              font=font(34, True), fill=INK)

    total = 0
    y = HEADER
    for slot in SLOTS:
        draw.text((28, y + 10), slot, font=font(26, True), fill=(212, 206, 228))
        y += ROW_TITLE
        for column, rarity in enumerate(ORDER):
            item_id = by_slot[slot].get(rarity)
            x = 20 + column * (CELL + 20)
            draw.rounded_rectangle([x, y, x + CELL, y + CELL + LABEL], radius=14, fill=CARD)
            if item_id is None:
                draw.text((x + 20, y + CELL // 2), "missing", font=font(24), fill=(220, 90, 90))
                continue
            icon_path = ICONS / f"{item_id}.webp"
            if not icon_path.exists():
                draw.text((x + 20, y + CELL // 2), "no file", font=font(24), fill=(220, 90, 90))
                continue
            icon = Image.open(icon_path).convert("RGBA").resize((CELL - 36, CELL - 36), Image.LANCZOS)
            sheet.paste(icon, (x + 18, y + 12), icon)
            draw.text((x + 18, y + CELL - 6), item_id, font=font(22, True), fill=INK)
            draw.text((x + 18, y + CELL + 24), f"slot: {slot}", font=font(19), fill=DIM)
            draw.text((x + 18, y + CELL + 50), f"rarity: {rarity}", font=font(19), fill=RARITY[rarity])
            total += 1
        y += CELL + LABEL + 18

    draw.text((width - 300, 30), f"{total} icons found", font=font(24), fill=INK)
    sheet.save(TARGET, "WEBP", quality=92, method=5)
    print(f"{TARGET}  {sheet.size[0]}x{sheet.size[1]}  {TARGET.stat().st_size / 1024:.0f} KB  icons={total}")


if __name__ == "__main__":
    main()
