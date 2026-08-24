# Biome Destructible Asset Sources

The eight runtime sprites in this directory were generated for Walker’s Wake with **GPT Image 2** using project gameplay art and shipped destructibles as style and isometric-projection references. The wetland, frozen-tundra, and lava-field assets were generated on 2026-08-20. The desert variants were generated on 2026-08-25.

The accepted runtime derivatives are 256 × 256 RGBA PNG files. Generated masters were alpha-cleaned, trimmed without cropping the subject, centered, and resized with Lanczos resampling. Desert master files and preview artifacts remain outside version control; `tools/prepare_desert_rock_sprites.py` reproducibly prepares their checked-in runtime derivatives. No external third-party art was incorporated.

| Runtime asset | Subject | SHA-256 |
|---|---|---|
| `desert_sandstone_cluster.png` | Sunscoured sandstone slab cluster | `2ac922ecbdcf25df328e09361e10ae5c0e112aebd7f4d91eb4f99dea25ed0a2e` |
| `desert_ironstone_outcrop.png` | Dense iron-rich desert outcrop | `028bbc2dd9268e9406a145849738f6ce37dea11b0344366dd62d90feb6bd95ed` |
| `wetland_mangrove.png` | Dead mangrove snag | — |
| `wetland_stump.png` | Rotting wetland stump | — |
| `frozen_snow_rock.png` | Snow-capped granite boulder | — |
| `frozen_pine.png` | Wind-bent frozen pine | — |
| `lava_basalt_chimney.png` | Columnar basalt chimney | — |
| `lava_obsidian_cluster.png` | Obsidian clinker cluster | — |
