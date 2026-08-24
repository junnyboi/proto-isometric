#!/usr/bin/env python3
"""Build disposable 16:9 keyframes for enemy SFX carrier-video generation."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / ".generated" / "enemy_sfx" / "carrier_frames"
ENTITIES: dict[str, tuple[str, tuple[int, int, int], tuple[int, int, int]]] = {
    "glassback_scarab": (
        "assets/enemies/tiny_mobs/glassback_scarab.png",
        (99, 63, 38),
        (218, 154, 73),
    ),
    "mire_tick": (
        "assets/enemies/tiny_mobs/mire_tick.png",
        (28, 55, 50),
        (92, 143, 98),
    ),
    "rime_shardling": (
        "assets/enemies/tiny_mobs/rime_shardling.png",
        (33, 50, 69),
        (118, 193, 226),
    ),
    "ember_skitter": (
        "assets/enemies/tiny_mobs/ember_skitter.png",
        (62, 31, 27),
        (224, 90, 43),
    ),
    "kilnheart_colossus": (
        "assets/enemies/kilnheart/kilnheart_idle.png",
        (47, 28, 30),
        (236, 103, 43),
    ),
}
WIDTH = 1280
HEIGHT = 720


def gradient(top: tuple[int, int, int], accent: tuple[int, int, int]) -> Image.Image:
    y = np.linspace(0.0, 1.0, HEIGHT, dtype=np.float32)[:, None, None]
    top_array = np.array(top, dtype=np.float32)[None, None, :]
    bottom = np.array(tuple(max(8, int(value * 0.42)) for value in accent), dtype=np.float32)[
        None, None, :
    ]
    rgb = top_array * (1.0 - y) + bottom * y
    rgb = np.broadcast_to(rgb, (HEIGHT, WIDTH, 3)).astype(np.uint8)
    return Image.fromarray(rgb, "RGB").convert("RGBA")


def build(name: str, source: str, top: tuple[int, int, int], accent: tuple[int, int, int]) -> None:
    frame = gradient(top, accent)
    draw = ImageDraw.Draw(frame, "RGBA")
    draw.ellipse((230, 500, 1050, 650), fill=(*accent, 42))
    draw.ellipse((340, 530, 940, 620), fill=(9, 10, 12, 118))
    glow = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow, "RGBA")
    glow_draw.ellipse((430, 205, 850, 625), fill=(*accent, 78))
    frame.alpha_composite(glow.filter(ImageFilter.GaussianBlur(68)))
    sprite = Image.open(ROOT / source).convert("RGBA")
    size = 390 if name == "kilnheart_colossus" else 310
    sprite.thumbnail((size, size), Image.Resampling.LANCZOS)
    x = WIDTH // 2 - sprite.width // 2
    y = 535 - sprite.height
    frame.alpha_composite(sprite, (x, y))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    path = OUTPUT / f"{name}.png"
    frame.convert("RGB").save(path, optimize=True)
    print(f"carrier_frame={path} size={frame.size}")


def main() -> None:
    for name, (source, top, accent) in ENTITIES.items():
        build(name, source, top, accent)


if __name__ == "__main__":
    main()
