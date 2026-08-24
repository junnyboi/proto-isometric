#!/usr/bin/env python3
"""Prepare GPT Image 2 Kilnheart masters as aligned Godot RGBA sprites."""

from __future__ import annotations

import argparse
import hashlib
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MASTER_DIR = ROOT / ".generated" / "kilnheart"
OUTPUT_DIR = ROOT / "assets" / "enemies" / "kilnheart"
PREVIEW_PATH = DEFAULT_MASTER_DIR / "kilnheart_runtime_preview.png"
ASSETS: dict[str, tuple[str, str]] = {
    "idle": ("kilnheart_idle_master.png", "kilnheart_idle.png"),
    "walk_a": ("kilnheart_walk_a_master.png", "kilnheart_walk_a.png"),
    "walk_b": ("kilnheart_walk_b_master.png", "kilnheart_walk_b.png"),
    "windup": ("kilnheart_windup_master.png", "kilnheart_windup.png"),
    "attack": ("kilnheart_attack_master.png", "kilnheart_attack.png"),
    "cracked": ("kilnheart_cracked_master.png", "kilnheart_cracked.png"),
    "broken": ("kilnheart_broken_master.png", "kilnheart_broken.png"),
    "defeat": ("kilnheart_defeat_master.png", "kilnheart_defeat.png"),
}
CANVAS_SIZE = 512
SUBJECT_MAX_WIDTH = 458
SUBJECT_MAX_HEIGHT = 430
CONTACT_Y = 478


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


def edge_connected(candidate: np.ndarray) -> np.ndarray:
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
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < height and 0 <= nx < width:
                queue.append((ny, nx))
    return visited


def background_mask(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    height, width, _ = rgb.shape
    corner = max(12, min(height, width) // 24)
    samples = np.concatenate(
        [
            rgb[:corner, :corner].reshape(-1, 3),
            rgb[:corner, -corner:].reshape(-1, 3),
            rgb[-corner:, :corner].reshape(-1, 3),
            rgb[-corner:, -corner:].reshape(-1, 3),
        ]
    ).astype(np.int16)
    reference = np.median(samples, axis=0)
    values = rgb.astype(np.int16)
    distance = np.sqrt(np.sum((values - reference) ** 2, axis=2))
    r, g, b = values[..., 0], values[..., 1], values[..., 2]
    green = (g > 68) & (g > r + 18) & (g > b + 10)
    close_background = distance < 48.0
    transparent = alpha < 8
    connected = edge_connected(close_background | green | transparent)
    enclosed_reference = distance < 28.0
    return connected | enclosed_reference | green | transparent


def prepare(master_dir: Path, key: str) -> Image.Image:
    source_name, output_name = ASSETS[key]
    source = master_dir / source_name
    image = Image.open(source).convert("RGBA")
    pixels = np.asarray(image).copy()
    alpha = pixels[..., 3].copy()
    background = background_mask(pixels[..., :3], alpha)
    fringe = dilate(background, 2)
    values = pixels[..., :3].astype(np.int16)
    r, g, b = values[..., 0], values[..., 1], values[..., 2]
    green_spill = (g > r + 10) & (g > b + 5) & fringe
    alpha[background | green_spill] = 0
    pixels[..., 3] = alpha
    pixels[alpha == 0, :3] = 0
    visible = alpha > 12
    if not visible.any():
        raise RuntimeError(f"{key}: no visible foreground after segmentation")
    ys, xs = np.nonzero(visible)
    left, right = int(xs.min()), int(xs.max()) + 1
    top, bottom = int(ys.min()), int(ys.max()) + 1
    crop = Image.fromarray(pixels, "RGBA").crop((left, top, right, bottom))
    scale = min(SUBJECT_MAX_WIDTH / crop.width, SUBJECT_MAX_HEIGHT / crop.height)
    size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    sprite = crop.resize(size, Image.Resampling.LANCZOS)
    sprite_pixels = np.asarray(sprite).copy()
    sprite_pixels[sprite_pixels[..., 3] == 0, :3] = 0
    sprite = Image.fromarray(sprite_pixels, "RGBA")
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    position = ((CANVAS_SIZE - sprite.width) // 2, CONTACT_Y - sprite.height)
    canvas.alpha_composite(sprite, position)
    output = OUTPUT_DIR / output_name
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, optimize=True)
    runtime = np.asarray(canvas)
    runtime_visible = runtime[..., 3] > 8
    out_y, out_x = np.nonzero(runtime_visible)
    print(
        f"{key}: source={image.size} crop={crop.size} runtime_bbox="
        f"({out_x.min()},{out_y.min()})-({out_x.max()},{out_y.max()}) "
        f"alpha={int(runtime[..., 3].min())}-{int(runtime[..., 3].max())} "
        f"sha256={sha256(output)}"
    )
    return canvas


def paste_scaled(canvas: Image.Image, sprite: Image.Image, center: tuple[int, int], size: int) -> None:
    scaled = sprite.resize((size, size), Image.Resampling.LANCZOS)
    canvas.alpha_composite(scaled, (center[0] - size // 2, center[1] - size // 2))


def make_preview(master_dir: Path, sprites: dict[str, Image.Image]) -> None:
    preview = Image.new("RGBA", (1600, 900), (33, 23, 25, 255))
    draw = ImageDraw.Draw(preview)
    draw.rectangle((0, 500, 1600, 900), fill=(92, 42, 30, 255))
    draw.polygon(((0, 570), (800, 388), (1600, 570), (800, 752)), fill=(73, 52, 49, 255))
    order = ("idle", "walk_a", "walk_b", "windup", "attack", "cracked", "broken", "defeat")
    labels = ("IDLE", "WALK A", "WALK B", "WINDUP", "ATTACK", "CRACKED", "BROKEN", "DEFEAT")
    for index, (key, label) in enumerate(zip(order, labels, strict=True)):
        column = index % 4
        row = index // 4
        x = 200 + column * 400
        y = 226 + row * 390
        draw.rounded_rectangle((x - 172, y - 178, x + 172, y + 164), radius=18, fill=(31, 37, 39, 230))
        paste_scaled(preview, sprites[key], (x, y - 4), 292)
        draw.text((x - 150, y + 136), label, fill=(255, 194, 103, 255))
    preview.save(PREVIEW_PATH, optimize=True)
    print(f"preview={PREVIEW_PATH}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--master-dir", type=Path, default=DEFAULT_MASTER_DIR)
    args = parser.parse_args()
    sprites = {key: prepare(args.master_dir, key) for key in ASSETS}
    make_preview(args.master_dir, sprites)


if __name__ == "__main__":
    main()
