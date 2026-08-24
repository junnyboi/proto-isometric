#!/usr/bin/env python3
"""Prepare generated Ironjaw Dune Burrower masters as Godot RGBA sprites."""

from __future__ import annotations

import argparse
import hashlib
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MASTER_DIR = ROOT / ".generated" / "sandworm"
OUTPUT_DIR = ROOT / "assets" / "enemies" / "sandworm"
PREVIEW_PATH = DEFAULT_MASTER_DIR / "runtime_sprite_preview.png"
PARTS = ("head", "body", "tail")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def dilate(mask: np.ndarray, radius: int) -> np.ndarray:
    expanded = mask.copy()
    for _ in range(radius):
        padded = np.pad(expanded, 1, mode="constant")
        expanded = np.logical_or.reduce(
            [
                padded[0:-2, 0:-2],
                padded[0:-2, 1:-1],
                padded[0:-2, 2:],
                padded[1:-1, 0:-2],
                padded[1:-1, 1:-1],
                padded[1:-1, 2:],
                padded[2:, 0:-2],
                padded[2:, 1:-1],
                padded[2:, 2:],
            ]
        )
    return expanded


def edge_connected_background(rgb: np.ndarray) -> np.ndarray:
    r = rgb[..., 0].astype(np.int16)
    g = rgb[..., 1].astype(np.int16)
    b = rgb[..., 2].astype(np.int16)
    maximum = np.maximum.reduce([r, g, b])
    minimum = np.minimum.reduce([r, g, b])
    chroma = maximum - minimum
    candidate = (
        ((g > 82) & (g > r + 24) & (g > b + 15))
        | (maximum < 54)
        | (chroma < 24)
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


def prepare_part(master_dir: Path, name: str) -> Image.Image:
    source = master_dir / f"ironjaw_dune_burrower_{name}_master.png"
    image = Image.open(source).convert("RGBA")
    pixels = np.asarray(image).copy()
    alpha = pixels[..., 3]
    background = edge_connected_background(pixels[..., :3])
    alpha[background] = 0
    fringe = dilate(background, 2)
    r = pixels[..., 0].astype(np.int16)
    g = pixels[..., 1].astype(np.int16)
    b = pixels[..., 2].astype(np.int16)
    green_spill = (g > r + 16) & (g > b + 8) & fringe
    alpha[green_spill] = 0
    pixels[..., 3] = alpha
    pixels[alpha == 0, :3] = 0
    image = Image.fromarray(pixels, "RGBA")
    visible = alpha > 8
    if not visible.any():
        raise RuntimeError(f"{name}: generated master has no visible pixels")
    if int(alpha.max()) < 250:
        raise RuntimeError(f"{name}: generated master never reaches opaque alpha")
    ys, xs = np.nonzero(visible)
    left, right = int(xs.min()), int(xs.max()) + 1
    top, bottom = int(ys.min()), int(ys.max()) + 1
    width, height = right - left, bottom - top
    padding = max(36, int(max(width, height) * 0.08))
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
        max(crop_box[0], 0),
        max(crop_box[1], 0),
        min(crop_box[2], image.width),
        min(crop_box[3], image.height),
    )
    paste_at = (source_box[0] - crop_box[0], source_box[1] - crop_box[1])
    square.alpha_composite(image.crop(source_box), paste_at)
    runtime = square.resize((512, 512), Image.Resampling.LANCZOS)
    runtime_pixels = np.asarray(runtime).copy()
    runtime_pixels[runtime_pixels[..., 3] == 0, :3] = 0
    runtime = Image.fromarray(runtime_pixels, "RGBA")
    output = OUTPUT_DIR / f"ironjaw_dune_burrower_{name}.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    runtime.save(output, optimize=True)
    runtime_visible = runtime_pixels[..., 3] > 8
    out_y, out_x = np.nonzero(runtime_visible)
    print(
        f"{name}: source={image.size} alpha={int(alpha.min())}-{int(alpha.max())} "
        f"runtime_bbox=({out_x.min()},{out_y.min()})-({out_x.max()},{out_y.max()}) "
        f"sha256={sha256(output)}"
    )
    return runtime


def paste_scaled(
    canvas: Image.Image, sprite: Image.Image, center: tuple[int, int], size: int, angle: float = 0.0
) -> None:
    part = sprite.resize((size, size), Image.Resampling.LANCZOS)
    if angle:
        part = part.rotate(angle, Image.Resampling.BICUBIC, expand=True)
    canvas.alpha_composite(part, (center[0] - part.width // 2, center[1] - part.height // 2))


def make_preview(master_dir: Path, parts: dict[str, Image.Image]) -> None:
    if set(parts) != set(PARTS):
        return
    preview = Image.new("RGBA", (1120, 520), (22, 24, 28, 255))
    draw = ImageDraw.Draw(preview)
    for index, name in enumerate(PARTS):
        x0 = 20 + index * 230
        draw.rounded_rectangle((x0, 20, x0 + 210, 250), radius=14, fill=(54, 44, 34, 255))
        paste_scaled(preview, parts[name], (x0 + 105, 132), 184)
        draw.text((x0 + 16, 226), name.upper(), fill=(238, 190, 108, 255))
    draw.rounded_rectangle((20, 278, 1100, 500), radius=16, fill=(138, 98, 49, 255))
    centers = [(780, 384), (710, 392), (642, 385), (578, 399), (516, 386)]
    paste_scaled(preview, parts["head"], centers[0], 152)
    for center, scale, angle in zip(centers[1:4], (108, 102, 96), (-7.0, 6.0, -5.0), strict=True):
        paste_scaled(preview, parts["body"], center, scale, angle)
    paste_scaled(preview, parts["tail"], centers[4], 92, 5.0)
    draw.text((40, 300), "ASSEMBLED GAMEPLAY-SCALE CHAIN", fill=(255, 231, 178, 255))
    preview_path = master_dir / "runtime_sprite_preview.png"
    preview.save(preview_path, optimize=True)
    print(f"preview={preview_path}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--master-dir", type=Path, default=DEFAULT_MASTER_DIR)
    parser.add_argument("--parts", nargs="+", choices=PARTS, default=list(PARTS))
    args = parser.parse_args()
    outputs = {name: prepare_part(args.master_dir, name) for name in args.parts}
    make_preview(args.master_dir, outputs)


if __name__ == "__main__":
    main()
