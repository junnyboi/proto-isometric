# Mud Skimmer runtime source

`mud_skimmer.png` was generated with **GPT Image 2** on 2026-08-19 as an original biome-native Oasis enemy for Walker's Wake. The accepted 1920×1920 transparent master remains outside Git. The runtime derivative removes residual temporary key-color pixels, trims the transparent canvas without cropping the creature, and downsamples the complete silhouette into a centered 512×512 RGBA PNG.

| Runtime file | SHA-256 |
|---|---|
| `mud_skimmer.png` | `70586b8d9c32f51aa05f045c977fe1476db0023ea2f8d857874a9c5bfdf898ec` |

Combat state, collision targeting, damage, rewards, and biome selection remain deterministic Godot logic; the image is presentation only.

## Rime Stalker

`rime_stalker.png` was generated with **GPT Image 2** on 2026-08-19 as an original Frozen Tundra enemy. Deterministic edge-connected key-color cleanup, hue decontamination, trimming, and Lanczos downsampling produced the centered 512×512 RGBA runtime sprite; the untouched master remains outside Git.

| Runtime file | SHA-256 |
|---|---|
| `rime_stalker.png` | `d271094736e97c6e5dc9cb674105806cf24a9a76f0d31b63d76e47a4ccc73ce5` |

## Cinder Crawler

`cinder_crawler.png` was generated with **GPT Image 2** on 2026-08-19 as an original Lava Fields enemy. Deterministic edge-connected key-color cleanup, hue decontamination, trimming, and Lanczos downsampling produced the centered 512×512 RGBA runtime sprite; the untouched master remains outside Git.

| Runtime file | SHA-256 |
|---|---|
| `cinder_crawler.png` | `4c0b01e47c0c507a981e7ebea7ef2e9bef9e1dedd909d4e9be07fd102d5af526` |

## Biome-specific tiny mobs

The four `tiny_mobs/*.png` sprites were generated with **GPT Image 2** on 2026-08-25 as original biome-native swarm enemies. `glassback_scarab.png` established the common southeast-facing three-quarter isometric camera, organic-mechanical material language, centered composition, and soft upper-left lighting. The wetland, frozen, and volcanic masters used that image as their shared style reference.

The accepted 1920 × 1920 masters remain outside Git. `tools/prepare_biome_mob_sprites.py` deterministically removes edge-connected temporary key colors or opaque background pixels, decontaminates color spill, trims without cropping the creature, centers the complete silhouette, and downsamples to transparent 512 × 512 RGBA runtime sprites.

| Runtime file | Biome | SHA-256 |
|---|---|---|
| `tiny_mobs/glassback_scarab.png` | Desert | `fc9124893366d4611a8b7e8a012634923d732d8e672c295dcade8a622be77447` |
| `tiny_mobs/mire_tick.png` | Oasis Wetlands | `cbbe4f7220dc1c8fa5155defeb2e4ea347f1ac512eddaf2a98c9afb67ed6e777` |
| `tiny_mobs/rime_shardling.png` | Frozen Tundra | `0ecd5851dd592926e2618405b89d57a9ccacc68cb2ca6852d7a4c9b57240f96c` |
| `tiny_mobs/ember_skitter.png` | Lava Fields | `38ee320b8ef4eed725d6309064d06ea780a12b9aae6f4415fc2ca5b13e146cf2` |

Combat state, targeting, damage, biome selection, and rewards remain deterministic Godot logic; these images are presentation assets only.

## Ironjaw Dune Burrower sandworm

The three `sandworm/*.png` sprites were generated with **GPT Image 2** on 2026-08-25 as an original modular replacement for the procedural desert sandworm body. `ironjaw_dune_burrower_head.png` established the creature identity: rust-red ferro-chitin, chipped sandstone cutting edges, near-black flexible joints, restrained cyan sensory pits, a right-facing three-quarter isometric camera, and soft upper-left lighting. The body and tail masters were image-to-image transformations of that accepted head so armor, connector geometry, perspective, and light remain consistent.

The 1920×1920 masters remain outside Git. `tools/prepare_sandworm_sprites.py` deterministically removes only edge-connected key/checkerboard backgrounds and their color fringe, trims complete silhouettes, centers each part, and downsamples to transparent 512×512 RGBA runtime sprites. The full production concept and exact prompts are recorded in `docs/plans/SANDWORM_SPRITE_CONCEPT.md`.

| Runtime file | Role | SHA-256 |
|---|---|---|
| `sandworm/ironjaw_dune_burrower_head.png` | Directional head and maw | `8787bfb2133230d743db49e4f3aa359253e992bd8c4a8a0b3b53a1c38971e82e` |
| `sandworm/ironjaw_dune_burrower_body.png` | Repeated armored body segment | `88083032d23a23337cd6ec24a53117af7d2e8d879ba1c44983fc408b2f5254a7` |
| `sandworm/ironjaw_dune_burrower_tail.png` | Tapered terminal segment | `91eea848cda7b9b43949c6bcee8def3b822874f162d0d57522dcf176623459f8` |

The textures replace exposed anatomy only. Burrow wakes, breach rings, attack telegraphs, health, hitboxes, damage, targeting, rewards, and state timing remain deterministic Godot logic.
