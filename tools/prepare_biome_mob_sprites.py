#!/usr/bin/env python3
"""Prepare generated biome mob masters as centered 512x512 Godot RGBA sprites."""

from __future__ import annotations

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
MASTER_DIR = ROOT / ".generated" / "biome_tiny_mobs"
OUTPUT_DIR = ROOT / "assets" / "enemies" / "tiny_mobs"
PREVIEW_PATH = MASTER_DIR / "runtime_sprite_preview.png"

SPRITES = {
    "glassback_scarab": {"key": "green"},
    "mire_tick": {"key": "magenta"},
    "rime_shardling": {"key": "magenta"},
    "ember_skitter": {"key": "opaque_teal"},
}


def chroma_mask(rgb: np.ndarray, key: str) -> np.ndarray:
    r = rgb[..., 0].astype(np.int16)
    g = rgb[..., 1].astype(np.int16)
    b = rgb[..., 2].astype(np.int16)
    if key == "green":
        return (g > 95) & (g > r + 34) & (g > b + 24)
    if key == "magenta":
        return (r > 100) & (b > 78) & (r > g + 42) & (b > g + 35)
    raise ValueError(key)


def flood_opaque_teal_background(rgb: np.ndarray) -> np.ndarray:
    r = rgb[..., 0].astype(np.int16)
    g = rgb[..., 1].astype(np.int16)
    b = rgb[..., 2].astype(np.int16)
    # The generated background is a low-luminance, low-chroma teal gradient.
    candidate = (
        (r < 72)
        & (g < 88)
        & (b < 92)
        & (g >= r - 4)
        & (b >= r - 7)
        & (np.maximum.reduce([r, g, b]) - np.minimum.reduce([r, g, b]) < 42)
    )
    height, width = candidate.shape
    visited = np.zeros_like(candidate, dtype=bool)
    queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        if candidate[0, x]:
            queue.append((0, x))
        if candidate[height - 1, x]:
            queue.append((height - 1, x))
    for y in range(height):
        if candidate[y, 0]:
            queue.append((y, 0))
        if candidate[y, width - 1]:
            queue.append((y, width - 1))
    while queue:
        y, x = queue.popleft()
        if visited[y, x] or not candidate[y, x]:
            continue
        visited[y, x] = True
        if y > 0:
            queue.append((y - 1, x))
        if y + 1 < height:
            queue.append((y + 1, x))
        if x > 0:
            queue.append((y, x - 1))
        if x + 1 < width:
            queue.append((y, x + 1))
    return visited


def dilate(mask: np.ndarray, radius: int) -> np.ndarray:
    expanded = mask.copy()
    for _ in range(radius):
        padded = np.pad(expanded, 1, mode="constant")
        neighbors = [
            padded[0:-2, 0:-2], padded[0:-2, 1:-1], padded[0:-2, 2:],
            padded[1:-1, 0:-2], padded[1:-1, 1:-1], padded[1:-1, 2:],
            padded[2:, 0:-2], padded[2:, 1:-1], padded[2:, 2:],
        ]
        expanded = np.logical_or.reduce(neighbors)
    return expanded


def prepare(name: str, config: dict[str, str]) -> Image.Image:
    source = MASTER_DIR / f"{name}_master.png"
    image = Image.open(source).convert("RGBA")
    pixels = np.array(image)
    rgb = pixels[..., :3]
    alpha = pixels[..., 3]
    key = config["key"]

    if key in {"green", "magenta"}:
        remove = chroma_mask(rgb, key)
        # Remove generated chroma streaks and the contaminated fringe around them.
        remove = dilate(remove, 1)
        alpha[remove] = 0
    else:
        background = flood_opaque_teal_background(rgb)
        alpha[background] = 0
        # Remove only edge-adjacent green spill, preserving orange magma and dark armor.
        transparent_edge = dilate(alpha == 0, 2)
        r = rgb[..., 0].astype(np.int16)
        g = rgb[..., 1].astype(np.int16)
        b = rgb[..., 2].astype(np.int16)
        green_spill = (g > r + 15) & (g > b + 5) & (r < 105) & transparent_edge
        alpha[green_spill] = 0

    pixels[..., 3] = alpha
    pixels[alpha == 0, :3] = 0
    cleaned = Image.fromarray(pixels, "RGBA")
    bbox = cleaned.getbbox()
    if bbox is None:
        raise RuntimeError(f"{name}: cleanup removed the entire sprite")
    left, top, right, bottom = bbox
    width = right - left
    height = bottom - top
    padding = max(48, int(max(width, height) * 0.055))
    side = max(width, height) + padding * 2
    center_x = (left + right) / 2.0
    center_y = (top + bottom) / 2.0
    crop_box = (
        int(round(center_x - side / 2.0)),
        int(round(center_y - side / 2.0)),
        int(round(center_x + side / 2.0)),
        int(round(center_y + side / 2.0)),
    )
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    source_box = (
        max(crop_box[0], 0), max(crop_box[1], 0),
        min(crop_box[2], cleaned.width), min(crop_box[3], cleaned.height),
    )
    paste_at = (source_box[0] - crop_box[0], source_box[1] - crop_box[1])
    square.alpha_composite(cleaned.crop(source_box), paste_at)
    runtime = square.resize((512, 512), Image.Resampling.LANCZOS)
    runtime_pixels = np.array(runtime)
    runtime_pixels[runtime_pixels[..., 3] == 0, :3] = 0
    runtime = Image.fromarray(runtime_pixels, "RGBA")
    output = OUTPUT_DIR / f"{name}.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    runtime.save(output, optimize=True)

    visible = runtime_pixels[..., 3] > 8
    visible_count = int(visible.sum())
    if visible_count == 0:
        raise RuntimeError(f"{name}: runtime sprite has no visible pixels")
    ys, xs = np.nonzero(visible)
    print(
        f"{name}: source={image.size} alpha={int(alpha.min())}-{int(alpha.max())} "
        f"runtime_bbox=({xs.min()},{ys.min()})-({xs.max()},{ys.max()}) "
        f"visible={visible_count} output={output.relative_to(ROOT)}"
    )
    return runtime


def make_preview(runtime_images: dict[str, Image.Image]) -> None:
    labels = {
        "glassback_scarab": "DESERT",
        "mire_tick": "WETLAND",
        "rime_shardling": "FROZEN",
        "ember_skitter": "LAVA",
    }
    backgrounds = {
        "glassback_scarab": (124, 93, 46, 255),
        "mire_tick": (38, 75, 66, 255),
        "rime_shardling": (108, 143, 158, 255),
        "ember_skitter": (61, 47, 47, 255),
    }
    sheet = Image.new("RGBA", (768, 232), (17, 20, 24, 255))
    draw = ImageDraw.Draw(sheet)
    for index, (name, sprite) in enumerate(runtime_images.items()):
        x0 = 16 + index * 188
        draw.rounded_rectangle((x0, 16, x0 + 172, 216), radius=12, fill=(28, 32, 38, 255))
        draw.rectangle((x0 + 12, 44, x0 + 160, 192), fill=backgrounds[name])
        tiny = sprite.resize((64, 64), Image.Resampling.LANCZOS)
        sheet.alpha_composite(tiny, (x0 + 54, 86))
        draw.text((x0 + 18, 24), labels[name], fill=(235, 239, 241, 255))
        draw.text((x0 + 18, 198), name, fill=(180, 190, 198, 255))
    sheet.save(PREVIEW_PATH, optimize=True)
    print(f"preview={PREVIEW_PATH.relative_to(ROOT)}")


def main() -> None:
    outputs = {name: prepare(name, config) for name, config in SPRITES.items()}
    make_preview(outputs)


if __name__ == "__main__":
    main()
