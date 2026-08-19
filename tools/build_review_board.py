#!/usr/bin/env python3
"""Compose one review board per resolution from the slice evidence.

Six screens across, English on the top row and Arabic on the bottom, so a
reviewer can compare a screen against its translation without opening files.

Usage: python3 tools/build_review_board.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

EVIDENCE = Path("docs/evidence/slice1")
OUT = Path("docs/evidence")
RESOLUTIONS = [(720, 1280), (1080, 1920), (1080, 2400)]
SCREENS = ["enemy", "boss", "inventory", "heroes", "skills", "equipment"]
TITLES = {
    "enemy": "Normal combat",
    "boss": "Boss combat",
    "inventory": "Inventory",
    "heroes": "Support heroes",
    "skills": "Skills",
    "equipment": "Equipment",
}
PANEL_H = 620
GAP = 18
HEADER = 54
LABEL = 34
BG = (18, 17, 24)
INK = (238, 236, 244)
DIM = (150, 148, 162)


def font(size: int) -> ImageFont.FreeTypeFont:
    for path in [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def build(width: int, height: int) -> Path:
    panels: dict[tuple[str, str], Image.Image] = {}
    for screen in SCREENS:
        for language in ("en", "ar"):
            source = EVIDENCE / f"{screen}_{language}_{width}x{height}.png"
            image = Image.open(source).convert("RGB")
            scale = PANEL_H / image.height
            panels[(screen, language)] = image.resize(
                (max(1, int(image.width * scale)), PANEL_H), Image.LANCZOS)

    panel_w = max(image.width for image in panels.values())
    board_w = GAP + len(SCREENS) * (panel_w + GAP)
    board_h = HEADER + 2 * (LABEL + PANEL_H + GAP) + GAP
    board = Image.new("RGB", (board_w, board_h), BG)
    draw = ImageDraw.Draw(board)
    draw.text((GAP, 14), f"Emerald Meadow slice - {width}x{height}", font=font(30), fill=INK)

    for column, screen in enumerate(SCREENS):
        x = GAP + column * (panel_w + GAP)
        for row, language in enumerate(("en", "ar")):
            y = HEADER + row * (LABEL + PANEL_H + GAP)
            caption = f"{TITLES[screen]} - {'English' if language == 'en' else 'Arabic (RTL)'}"
            # Tall captures make narrow panels; shrink the caption rather than
            # letting neighbouring labels run into each other.
            caption_font = font(20 if panel_w >= 330 else 15)
            draw.text((x, y + 6), caption, font=caption_font, fill=INK if row == 0 else DIM)
            image = panels[(screen, language)]
            board.paste(image, (x + (panel_w - image.width) // 2, y + LABEL))

    target = OUT / f"slice1_review_{width}x{height}.webp"
    board.save(target, "WEBP", quality=88, method=5)
    print(f"{target}  {board.size[0]}x{board.size[1]}  {target.stat().st_size / 1024:.0f} KB")
    return target


def main() -> None:
    for width, height in RESOLUTIONS:
        build(width, height)


if __name__ == "__main__":
    main()
