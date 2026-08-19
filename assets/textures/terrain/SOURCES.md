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

## Lava Fields

`lava_basalt.png`, `volcanic_ash.png`, and `lava_flow.png` were generated with **GPT Image 2** on 2026-08-19 and processed through the default-threshold seamless salvage workflow. Their 512×512 RGB derivatives and 3×3 previews passed objective and visual checks; raw masters and QA files remain outside Git.

| Runtime file | SHA-256 |
|---|---|
| `lava_basalt.png` | `d2327cfea86c29f3133eaac03a12583d7ae04ce9adbf427da72afc02b8d3967d` |
| `volcanic_ash.png` | `8d4352bf34aea0d6c6200cb1d51f858556db2010c78dd93f3b40510977d017c9` |
| `lava_flow.png` | `2c317efc3b1ae9c8853d14e6b3d5e990b5309880598a15e822f3b5804f433247` |
