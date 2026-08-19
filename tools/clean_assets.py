#!/usr/bin/env python3
"""Turn concept crops from the asset package into production sprites.

The package's crops keep the reference sheet's flat background wherever it is
enclosed by the silhouette (inside a bow's arc, between a treant's legs), plus
occasional fragments of the neighbouring character along the crop border. Both
would render as beige blobs in game, so they are removed here rather than at
runtime.

Usage: python3 tools/clean_assets.py [--check]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

PACKAGE = Path("CLAUDE_READY_CARTOON_ASSET_BIBLE")
OUT_ROOT = Path("assets/sprites")
SELECTION = Path("tools/asset_selection.json")

# The reference sheets are painted on one flat colour; sampled from
# assets/reference_sheets/base.webp, whose most common pixel this is.
SHEET_BG = np.array([253, 244, 224], dtype=np.int16)
COLOUR_TOLERANCE = 26          # per-channel distance still counted as background
FLATNESS_LIMIT = 7.0           # per-channel std-dev inside a region that may be sheet
MIN_REGION_PX = 6              # ignore single stray pixels
FRAGMENT_FRACTION = 0.06       # island smaller than this share of the body
PADDING = 2


def _cream_signature(rgb: np.ndarray) -> np.ndarray:
    """The reference sheet's own colour, identified by its warm cast.

    Matching a plain distance to (253,244,224) also matches white fur and pale
    ice, which are real artwork. The sheet is reliably warmer than neutral:
    red sits well above blue, and green between them.
    """
    r = rgb[:, :, 0].astype(np.int16)
    g = rgb[:, :, 1].astype(np.int16)
    b = rgb[:, :, 2].astype(np.int16)
    warm = (r - b >= 14) & (r - b <= 44)
    return (r >= 234) & (g >= 222) & (g <= 252) & (b >= 200) & (b <= 238) & warm & (g <= r) & (g >= b)


def _outside_bleed(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Everything the sheet left behind that is still reachable from outside.

    The package cut the outer background but kept the drop shadow and the pale
    halo around it. Both connect to the transparent exterior, and the artwork's
    bold dark outline blocks the fill, so growing outward from the transparent
    pixels removes them without touching the subject's own light areas.
    """
    value = rgb.max(axis=2).astype(np.int16)
    low = rgb.min(axis=2).astype(np.int16)
    saturation = np.where(value > 0, (value - low) / np.maximum(value, 1), 0.0)
    passable = ((value >= 196) & (saturation <= 0.28)) | _cream_signature(rgb)
    seed = alpha == 0
    region = passable | seed
    labels, count = ndimage.label(region)
    if count == 0:
        return np.zeros_like(seed)
    outside = np.unique(labels[seed]) if seed.any() else np.array([], dtype=int)
    outside = outside[outside > 0]
    bleed = np.isin(labels, outside) & ~seed
    return bleed


def _enclosed_sheet(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Sheet colour sealed inside the silhouette (a bow's arc, a leg gap)."""
    candidate = _cream_signature(rgb) & (alpha > 0)
    labels, count = ndimage.label(candidate)
    mask = np.zeros_like(candidate)
    for index in range(1, count + 1):
        region = labels == index
        if int(region.sum()) < MIN_REGION_PX:
            continue
        if float(rgb[region].std(axis=0).max()) > FLATNESS_LIMIT:
            continue
        mask |= region
    return mask


def _drop_border_fragments(alpha: np.ndarray) -> np.ndarray:
    """Remove leftovers of the neighbouring sheet character.

    They always enter from a crop edge and are small next to the subject, while
    a legitimate detached part (a spark, a thrown leaf) floats inside the frame.
    """
    solid = alpha > 8
    labels, count = ndimage.label(solid)
    if count <= 1:
        return alpha
    sizes = ndimage.sum(solid, labels, range(1, count + 1))
    body = int(np.argmax(sizes)) + 1
    height, width = alpha.shape
    cleaned = alpha.copy()
    for index in range(1, count + 1):
        if index == body:
            continue
        region = labels == index
        rows, cols = np.where(region)
        touches_edge = (
            rows.min() == 0 or cols.min() == 0
            or rows.max() == height - 1 or cols.max() == width - 1
        )
        if touches_edge and sizes[index - 1] < sizes[body - 1] * FRAGMENT_FRACTION:
            cleaned[region] = 0
    return cleaned


def _decontaminate(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Undo the sheet colour mixed into partly transparent edge pixels.

    Those pixels were composited over the sheet, so leaving them produces a pale
    halo on a dark world background.
    """
    edge = (alpha > 0) & (alpha < 250)
    if not edge.any():
        return rgb
    out = rgb.astype(np.float32).copy()
    a = (alpha[edge].astype(np.float32) / 255.0)[:, None]
    mixed = out[edge]
    out[edge] = np.clip((mixed - (1.0 - a) * SHEET_BG.astype(np.float32)) / np.maximum(a, 0.05), 0, 255)
    return out.astype(np.uint8)


def clean(path: Path) -> tuple[Image.Image, dict]:
    image = Image.open(path).convert("RGBA")
    data = np.array(image)
    rgb, alpha = data[:, :, :3], data[:, :, 3]

    removal = _outside_bleed(rgb, alpha) | _enclosed_sheet(rgb, alpha)
    before = int((removal & (alpha > 0)).sum())
    alpha = np.where(removal, 0, alpha)
    alpha = _drop_border_fragments(alpha)

    # One-pixel feather so the silhouette does not read as stair-stepped, then
    # remove the sheet colour that anti-aliasing baked into the edge.
    soft = ndimage.gaussian_filter(alpha.astype(np.float32), sigma=0.6)
    alpha = np.where(alpha > 0, np.maximum(alpha, soft * 0.9), soft * 0.55).astype(np.uint8)
    alpha[alpha < 6] = 0
    rgb = _decontaminate(rgb, alpha)

    result = Image.fromarray(np.dstack([rgb, alpha]), "RGBA")
    box = result.getbbox()
    if box is not None:
        left = max(0, box[0] - PADDING)
        top = max(0, box[1] - PADDING)
        right = min(result.width, box[2] + PADDING)
        bottom = min(result.height, box[3] + PADDING)
        result = result.crop((left, top, right, bottom))
    stats = {
        "removed_background_px": before,
        "size": list(result.size),
    }
    return result, stats


def main() -> None:
    selection = json.loads(SELECTION.read_text())
    report: dict[str, dict] = {}
    for entry in selection["assets"]:
        source = PACKAGE / entry["source"]
        target = OUT_ROOT / entry["target"]
        target.parent.mkdir(parents=True, exist_ok=True)
        image, stats = clean(source)
        image.save(target)
        report[entry["target"]] = stats
        print(f"{entry['target']:44s} removed={stats['removed_background_px']:6d} px  -> {stats['size']}")
    total = sum(item["removed_background_px"] for item in report.values())
    print(f"\n{len(report)} sprites written, {total} background pixels removed")


if __name__ == "__main__":
    main()
