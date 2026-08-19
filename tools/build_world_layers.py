#!/usr/bin/env python3
"""Rebuild a concept world painting as four separate parallax layers.

The package ships each world as one flat 540x959 image. A parallax background
needs the depths apart, so the painting is segmented by its own composition
(sky by colour, then arena and foreground by the bands the painting itself
uses), each part is resampled onto the 1080x1920 master canvas, and the layers
that move fastest are widened so there is real travel room instead of an edge
appearing at the first scroll.

Usage: python3 tools/build_world_layers.py <world_id> [more_ids...]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

PACKAGE = Path("CLAUDE_READY_CARTOON_ASSET_BIBLE/assets/worlds")
OUT_ROOT = Path("assets/worlds")
MASTER = (1080, 1920)
# How much wider than the viewport each layer is drawn. Nearer layers scroll
# further per unit of camera movement, so they need more slack.
WIDTH_SCALE = {"sky": 1.0, "distant": 1.18, "arena": 1.0, "foreground": 1.12}
# Texture memory is the real cost of a four-layer background on a phone. The
# back layers carry soft, low-detail content and are stored smaller; the arena
# and foreground, which sit directly behind the actors, stay at full master
# resolution. The rects scale each layer back up to the same on-screen size.
RESOLUTION_SCALE = {"sky": 0.5, "distant": 0.7, "arena": 1.0, "foreground": 0.85}
FEATHER = 26


def _feather(mask: np.ndarray, radius: int = FEATHER) -> np.ndarray:
    return np.clip(ndimage.gaussian_filter(mask.astype(np.float32), sigma=radius / 2.5), 0.0, 1.0)


def _sky_mask(rgb: np.ndarray) -> np.ndarray:
    """Sky is the blue region connected to the top edge."""
    height = rgb.shape[0]
    blueness = rgb[:, :, 2].astype(np.int16) - rgb[:, :, 0].astype(np.int16)
    value = rgb.max(axis=2).astype(np.int16)
    low = rgb.min(axis=2).astype(np.int16)
    # Open sky only. Hazy blue mountains also read as blue, but they belong to
    # the distant layer; keeping them here would ghost against it.
    candidate = ((blueness > 58) & (value > 150)) | ((value > 232) & (value - low < 34))
    candidate[int(height * 0.46):, :] = False
    labels, count = ndimage.label(candidate)
    keep = np.unique(labels[0, :])
    keep = keep[keep > 0]
    if keep.size == 0:
        candidate[: int(height * 0.2), :] = True
        return candidate
    return np.isin(labels, keep)


def _sky_plate(rgb: np.ndarray, sky: np.ndarray) -> np.ndarray:
    """A sky-only plate that still covers the whole canvas.

    Everything that is not sky (mountains, ruins, trees) belongs to the distant
    layer; drawing it here as well would ghost, because the two layers scroll at
    different speeds. Those pixels are replaced by the sky's own vertical colour
    profile, continued below the horizon so the plate never shows a hole when it
    parallaxes.
    """
    height, width, _ = rgb.shape
    profile = np.zeros((height, 3), dtype=np.float32)
    last_valid = None
    for y in range(height):
        row = sky[y]
        if row.any():
            profile[y] = rgb[y][row].mean(axis=0)
            last_valid = profile[y].copy()
        elif last_valid is not None:
            profile[y] = last_valid
        else:
            profile[y] = rgb[y].mean(axis=0)
    # Below the horizon the sky is never seen directly, so it only has to stay
    # plausible: ease it a little darker instead of repeating one flat row.
    horizon = int(np.argmax(sky.sum(axis=1)[::-1] > 0))
    horizon_row = height - 1 - horizon
    for y in range(horizon_row, height):
        fade = min(1.0, (y - horizon_row) / max(1.0, height - horizon_row))
        profile[y] = profile[horizon_row] * (1.0 - 0.35 * fade)
    plate = np.repeat(profile[:, None, :], width, axis=1)
    blended = np.where(sky[:, :, None], rgb.astype(np.float32), plate)
    blended = ndimage.gaussian_filter(blended, sigma=(0.0, 6.0, 0.0))
    blended = np.where(sky[:, :, None], rgb.astype(np.float32), blended)
    return np.clip(blended, 0, 255).astype(np.uint8)


def _sky_master(rgb: np.ndarray, sky: np.ndarray) -> np.ndarray:
    """The sky plate, authored at the master canvas size."""
    height, width, _ = rgb.shape
    plate = _sky_plate(rgb, sky)
    target = Image.fromarray(plate, "RGB").resize(MASTER, Image.LANCZOS)
    # Re-evaluate the vertical gradient at master height so its banding is not
    # an upscaled copy of a 959-row ramp.
    profile = np.zeros((height, 3), dtype=np.float32)
    last = None
    for y in range(height):
        row = sky[y]
        if row.any():
            profile[y] = rgb[y][row].mean(axis=0)
            last = profile[y].copy()
        elif last is not None:
            profile[y] = last
        else:
            profile[y] = rgb[y].mean(axis=0)
    horizon = int(np.argmax(sky.sum(axis=1)[::-1] > 0))
    horizon_row = height - 1 - horizon
    for y in range(horizon_row, height):
        fade = min(1.0, (y - horizon_row) / max(1.0, height - horizon_row))
        profile[y] = profile[horizon_row] * (1.0 - 0.35 * fade)
    source_rows = np.linspace(0.0, height - 1.0, MASTER[1])
    fine = np.stack([np.interp(source_rows, np.arange(height), profile[:, channel])
                     for channel in range(3)], axis=1)
    gradient = np.repeat(fine[:, None, :], MASTER[0], axis=1)
    cloud_mask = np.array(Image.fromarray((sky * 255).astype(np.uint8)).resize(MASTER, Image.BILINEAR)).astype(np.float32) / 255.0
    blended = np.array(target).astype(np.float32) * cloud_mask[:, :, None] + gradient * (1.0 - cloud_mask[:, :, None])
    return np.dstack([np.clip(blended, 0, 255).astype(np.uint8),
                      np.full((MASTER[1], MASTER[0]), 255, np.uint8)])


def _band(height: int, top: float, bottom: float) -> np.ndarray:
    mask = np.zeros(height, dtype=bool)
    mask[int(height * top):int(height * bottom)] = True
    return mask


def build(world_id: str) -> dict:
    source = Image.open(PACKAGE / f"{world_id}.webp").convert("RGB")
    rgb = np.array(source)
    height, width, _ = rgb.shape

    sky = _sky_mask(rgb)
    # Where the sky stops is where the distant scenery starts; the arena and
    # the foreground follow the bands the painting is composed in.
    sky_bottom = float(np.argmax(sky.sum(axis=1)[::-1] > 0))
    sky_bottom = 1.0 - sky_bottom / height
    arena_top, arena_bottom, foreground_top = 0.46, 0.80, 0.74

    rows = np.arange(height)[:, None]
    distant = (~sky) & (rows < int(height * arena_top + FEATHER))
    arena = (rows >= int(height * arena_top)) & (rows < int(height * arena_bottom))
    foreground = rows >= int(height * foreground_top)
    # The framing plants that run up the sides belong in front of the arena.
    green = (rgb[:, :, 1].astype(np.int16) - rgb[:, :, 0].astype(np.int16) > 18) & (rgb.max(axis=2) < 190)
    side = np.zeros((height, width), dtype=bool)
    side[:, : int(width * 0.13)] = True
    side[:, int(width * 0.87):] = True
    foreground = foreground | (green & side & (rows > int(height * 0.5)))

    layers = {
        "sky": np.ones((height, width), dtype=bool),
        "distant": distant & np.ones((1, width), dtype=bool),
        "arena": arena & np.ones((1, width), dtype=bool),
        "foreground": foreground,
    }

    OUT_ROOT.joinpath(world_id).mkdir(parents=True, exist_ok=True)
    report: dict[str, dict] = {}
    for name, mask in layers.items():
        alpha = np.ones((height, width), dtype=np.float32) if name == "sky" else _feather(mask)
        if name == "sky":
            # Built straight onto the master canvas: the gradient is evaluated
            # at 1920 rows instead of being painted at 540 and then stretched,
            # so the sky has no resampling softness of its own. Only the cloud
            # pixels still come from the concept and are resampled once.
            layer = _sky_master(rgb, sky)
        else:
            layer = np.dstack([rgb, (alpha * 255).astype(np.uint8)])
        image = Image.fromarray(layer, "RGBA")
        if name == "sky":
            out = OUT_ROOT / world_id / "sky.png"
            image.save(out)
            covered = 1.0
            report[name] = {
                "file": str(out),
                "stored_size": list(image.size),
                "drawn_width_vs_viewport": WIDTH_SCALE[name],
                "coverage": 1.0,
            }
            print(f"  {name:11s} {image.size[0]}x{image.size[1]}  coverage=100.0%  -> {out}")
            continue
        detail: float = RESOLUTION_SCALE[name]
        target_width = int(MASTER[0] * WIDTH_SCALE[name] * detail)
        image = image.resize((target_width, int(MASTER[1] * detail)), Image.LANCZOS)
        out = OUT_ROOT / world_id / f"{name}.png"
        image.save(out)
        covered = float((np.array(image)[:, :, 3] > 8).mean())
        report[name] = {
            "file": str(out),
            "stored_size": list(image.size),
            "drawn_width_vs_viewport": WIDTH_SCALE[name],
            "coverage": round(covered, 3),
        }
        print(f"  {name:11s} {image.size[0]}x{image.size[1]}  coverage={covered:.1%}  -> {out}")
    return report


def main() -> None:
    ids = sys.argv[1:] or ["oasis_frontier"]
    report = {}
    for world_id in ids:
        print(world_id)
        report[world_id] = build(world_id)
    Path("assets/worlds/layers.json").write_text(json.dumps(report, indent=1) + "\n")


if __name__ == "__main__":
    main()
