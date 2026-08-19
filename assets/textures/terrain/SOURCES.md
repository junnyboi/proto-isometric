# Oasis / Wetlands runtime sources

The `oasis_wetland.png` and `dark_mud.png` albedo textures were generated with **GPT Image 2** on 2026-08-19 as orthographic, repeating Godot terrain materials. Raw 1920×1920 masters remain outside Git. The project `godot-texture-generator` salvage workflow produced 512×512 RGB runtime derivatives using periodic seam shifting, bounded feathering, exact edge matching, and Lanczos downsampling. Both default-threshold seam reports passed and their 3×3 previews were visually accepted.

| Runtime file | SHA-256 |
|---|---|
| `oasis_wetland.png` | `0ea02a38b94f5caea44be1d91697e7ab679fd416dd5278f05e475f6645cdad37` |
| `dark_mud.png` | `cf882c47f404fe69ddea35ec34c1144a1ac3ebde9c7577d11e21ec056c315c8d` |

The generated assets are original production derivatives for Walker's Wake. Geometry, terrain identity, collision, and gameplay behavior are authored deterministically in Godot and are not inferred from image pixels.
