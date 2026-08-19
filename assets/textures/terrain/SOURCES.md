# Oasis / Wetlands runtime sources

The `oasis_wetland.png` and `dark_mud.png` albedo textures were generated with **GPT Image 2** on 2026-08-19 as orthographic, repeating Godot terrain materials. Raw 1920×1920 masters remain outside Git. The project `godot-texture-generator` salvage workflow produced 512×512 RGB runtime derivatives using periodic seam shifting, bounded feathering, exact edge matching, and Lanczos downsampling. Both default-threshold seam reports passed and their 3×3 previews were visually accepted.

| Runtime file | SHA-256 |
|---|---|
| `oasis_wetland.png` | `0ea02a38b94f5caea44be1d91697e7ab679fd416dd5278f05e475f6645cdad37` |
| `dark_mud.png` | `cf882c47f404fe69ddea35ec34c1144a1ac3ebde9c7577d11e21ec056c315c8d` |

The generated assets are original production derivatives for Walker's Wake. Geometry, terrain identity, collision, and gameplay behavior are authored deterministically in Godot and are not inferred from image pixels.

## Frozen Tundra

`tundra_snow.png` and `blue_ice.png` were generated with **GPT Image 2** on 2026-08-19 and processed through the same default-threshold seamless salvage workflow. Their 512×512 RGB derivatives and 3×3 previews passed objective and visual checks; raw masters and QA files remain outside Git.

| Runtime file | SHA-256 |
|---|---|
| `tundra_snow.png` | `e28b84df4f8e6d9db54becafe485c6ffb95e3fd9b41583bbce5bec1f6ff58c4e` |
| `blue_ice.png` | `3d2cb8e9f6b208f27474add6ace8c83f49ec4c77bcabce957254c54519923f0d` |
