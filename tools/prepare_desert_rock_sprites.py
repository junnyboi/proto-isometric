#!/usr/bin/env python3
"""Prepare GPT Image 2 desert-rock masters as clean 256px Godot sprites."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
MASTER_DIR = ROOT / ".generated" / "desert_rocks"
OUTPUT_DIR = ROOT / "assets" / "destructibles"
PREVIEW_PATH = MASTER_DIR / "desert_rock_runtime_preview.png"
TARGET_SIZE = 256
SUBJECT_SIZE = 222

ASSETS = {
    "desert_sandstone_cluster": MASTER_DIR / "desert_sandstone_cluster_master.png",
    "desert_ironstone_outcrop": MASTER_DIR / "desert_ironstone_outcrop_master.png",
}


def key_color_mask(rgb: np.ndarray) -> np.ndarray:
    red = rgb[..., 0].astype(np.float32)
    green = rgb[..., 1].astype(np.float32)
    blue = rgb[..., 2].astype(np.float32)
    magenta = (
        (red > 55)
        & (blue > 45)
        & (green < np.minimum(red, blue) * 0.78)
        & (blue > red * 0.48)
    )
    chroma_green = (
        (green > 45)
        & (green > red * 1.34)
        & (green > blue * 1.25)
    )
    return magenta | chroma_green


def clean_master(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    data = np.asarray(image).copy()
    key_mask = key_color_mask(data[..., :3])
    data[key_mask, 3] = 0

    alpha = data[..., 3]
    visible = alpha > 8
    if not np.any(visible):
        raise RuntimeError(f"{path.name}: no visible subject after key cleanup")

    ys, xs = np.nonzero(visible)
    left = max(int(xs.min()) - 14, 0)
    top = max(int(ys.min()) - 14, 0)
    right = min(int(xs.max()) + 15, image.width)
    bottom = min(int(ys.max()) + 15, image.height)
    cropped = Image.fromarray(data, mode="RGBA").crop((left, top, right, bottom))

    scale = min(SUBJECT_SIZE / cropped.width, SUBJECT_SIZE / cropped.height)
    resized = cropped.resize(
        (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (TARGET_SIZE, TARGET_SIZE), (0, 0, 0, 0))
    x = (TARGET_SIZE - resized.width) // 2
    y = TARGET_SIZE - resized.height - 14
    canvas.alpha_composite(resized, (x, y))

    final = np.asarray(canvas).copy()
    final_key = key_color_mask(final[..., :3]) & (final[..., 3] > 0)
    final[final_key, 3] = 0
    return Image.fromarray(final, mode="RGBA")


def build_preview(outputs: dict[str, Image.Image]) -> None:
    preview = Image.new("RGBA", (720, 360), (18, 24, 31, 255))
    draw = ImageDraw.Draw(preview)
    sand = (137, 100, 53, 255)
    labels = {
        "desert_sandstone_cluster": "SUNSCOURED SANDSTONE",
        "desert_ironstone_outcrop": "IRONSTONE KNUCKLE",
    }
    for index, (name, sprite) in enumerate(outputs.items()):
        x0 = 20 + index * 350
        draw.rounded_rectangle((x0, 20, x0 + 330, 340), radius=10, fill=(39, 49, 61, 255))
        draw.text((x0 + 14, 34), labels[name], fill=(242, 246, 250, 255))
        draw.polygon(
            [
                (x0 + 55, 258),
                (x0 + 165, 205),
                (x0 + 275, 258),
                (x0 + 165, 311),
            ],
            fill=sand,
        )
        gameplay = sprite.resize((112, 112), Image.Resampling.LANCZOS)
        preview.alpha_composite(gameplay, (x0 + 109, 160))
        preview.alpha_composite(sprite, (x0 + 37, 72))
    preview.save(PREVIEW_PATH)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    outputs: dict[str, Image.Image] = {}
    for name, master_path in ASSETS.items():
        sprite = clean_master(master_path)
        output_path = OUTPUT_DIR / f"{name}.png"
        sprite.save(output_path, optimize=True)
        outputs[name] = sprite
        alpha = np.asarray(sprite)[..., 3]
        ys, xs = np.nonzero(alpha > 8)
        print(
            f"{name}: size={sprite.size} visible_bounds="
            f"({xs.min()},{ys.min()})-({xs.max()},{ys.max()}) alpha_pixels={len(xs)}"
        )
    build_preview(outputs)
    print(f"preview={PREVIEW_PATH}")


if __name__ == "__main__":
    main()
