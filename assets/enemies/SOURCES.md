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

## Ironjaw Apex boss and burrow transitions

The seven `ironjaw_apex_*.png` armor sprites and three `ironjaw_burrow_*.png` transition frames were generated with **GPT Image 2** on 2026-08-25 as an original boss extension of the accepted Ironjaw Dune Burrower. The intact Apex head establishes a wider crowned silhouette; cracked and broken image-to-image variants progressively expose hotter inner chitin while preserving camera, connector geometry, and upper-left lighting. The ordered burrow sequence advances from a low sand ridge through a split crest to a pre-breach crown.

The accepted masters remain outside Git. `tools/prepare_sandworm_sprites.py --set boss` applies the same edge-connected background cleanup, fringe decontamination, trim, centering, and Lanczos downsampling used for the standard creature, producing transparent 512×512 RGBA runtime sprites. The full combat, animation, prompt, and acceptance contract is recorded in `docs/plans/IRONJAW_APEX_BOSS_DESIGN.md`.

| Runtime file | Role | SHA-256 |
|---|---|---|
| `sandworm/ironjaw_apex_head.png` | Intact crowned boss head | `e22ec0e4e496eb6bc9d73ee393bc2e149972bee8db5149fb71395a54eb1f26f2` |
| `sandworm/ironjaw_apex_body.png` | Intact modular armor segment | `e0d917d5ce0c3c5da7d3354179461f39fdb83f43eea11c7b86dcc44905df329d` |
| `sandworm/ironjaw_apex_tail.png` | Reinforced terminal segment | `267efe6223f56e96b2047c4ceba17f053ba6c6e4145b8ae3d344973ff85ce63c` |
| `sandworm/ironjaw_apex_head_cracked.png` | First armor-break head | `1d96af8675e971b6db802bb24ece56ac27398dccb910f5d9f1efc2cb3386e810` |
| `sandworm/ironjaw_apex_body_cracked.png` | First armor-break body | `2d81e9b63e64187888aa0c400dec83e1706739de910abecd99b209cef0b17d8d` |
| `sandworm/ironjaw_apex_head_broken.png` | Final exposed-core head | `537dc176c0602e95bf7fd29f1ee51320522626108dd1d68bc6217542c0a686d9` |
| `sandworm/ironjaw_apex_body_broken.png` | Final exposed-core body | `0e2d6642108e93eb067310b9c4bcf3505a3b11f0d7a5f88c915c56dfe77bc96e` |
| `sandworm/ironjaw_burrow_01.png` | Low submerged ridge | `756bcda1a633698ad56d4607396dcb3ffa4aec068cab74bc454cd3e272bc6cd8` |
| `sandworm/ironjaw_burrow_02.png` | Split medium crest | `6741db9ab50502da42ec2777586700e7ab9274a195191b4d529bbf7cc12cfa76` |
| `sandworm/ironjaw_burrow_03.png` | High pre-breach crown | `91e170467eca48dc8f485206d6bd682c76811908d938192ead7c274830d92ff3` |

Boss health, armor thresholds, attack selection, telegraph geometry, hit testing, sanctuary cancellation, encounter spawning, and defeat persistence remain deterministic Godot logic; the generated images are presentation assets only.


## Kilnheart Colossus volcanic boss

The eight `kilnheart/*.png` sprites were generated with **GPT Image 2** on 2026-08-25 as an original Lava Fields boss. `kilnheart_idle.png` established the six-legged basalt siege-creature identity, exposed furnace core, orange magma seams, broad forelimbs, southeast-facing three-quarter isometric camera, and soft upper-left lighting. The locomotion, windup, attack, cracked, broken, and defeat masters used the accepted idle image as their shared identity and camera reference.

The 1920 × 1920 masters remain outside Git. `tools/prepare_kilnheart_sprites.py` deterministically removes edge-connected temporary backgrounds and green spill, decontaminates alpha edges, trims without cropping anatomy, aligns every standing pose to a common ground contact, centers the complete silhouette, and downsamples to transparent 512 × 512 RGBA runtime sprites. The full combat, animation, prompt, and acceptance contract is recorded in `docs/plans/KILNHEART_COLOSSUS_BOSS_DESIGN.md` and `docs/plans/KILNHEART_BOSS_IMAGE_PROMPTS.md`.

| Runtime file | Animation or damage role | SHA-256 |
|---|---|---|
| `kilnheart/kilnheart_idle.png` | Intact idle and recovery anchor | `33ce02ebcce17f025d1e942faed72a900cd0af864031b969610f76c5c2feaf36` |
| `kilnheart/kilnheart_walk_a.png` | First locomotion contact pose | `b7f997914c997cca7a6b3bdba174978e35eea552e93af45dd31f9a8a598ba6bd` |
| `kilnheart/kilnheart_walk_b.png` | Complementary locomotion contact pose | `615ffbd42258760ad10b78ed95cdc95b13a884a42d422b7eeb8e6166804cb893` |
| `kilnheart/kilnheart_windup.png` | Compressed warning pose | `af4fcddc85670c1eec88644d12c575120430a5a9f3d956a47b585f04c2529ec1` |
| `kilnheart/kilnheart_attack.png` | Attack-release pose | `eadc26306a0bac3b24156dfd1186dbeb68d192cbc14fb6f128cb07edaa461f76` |
| `kilnheart/kilnheart_cracked.png` | First armor-threshold presentation | `894291bb7cce22672281b0d1c208a58afd6d278793b0e4cca4960709365c375e` |
| `kilnheart/kilnheart_broken.png` | Final exposed-core presentation | `71dcc0c628cd21f07585172c90f77182d9f4678d4bd040f466c995e508d9f580` |
| `kilnheart/kilnheart_defeat.png` | Collapsed defeat presentation | `026a4024dbaad2b6ec4d156c05de12f3c6432f57635581f9a1d1e4ef5fe88144` |

Boss health, three-pattern rotation, phase acceleration, warning geometry, damage resolution, biome-exclusive encounter spawning, sound triggers, accessibility behavior, targeting, rewards, and defeat persistence remain deterministic Godot logic; the generated images are presentation assets only.
