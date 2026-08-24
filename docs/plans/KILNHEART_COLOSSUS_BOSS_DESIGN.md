# Kilnheart Colossus — Volcanic Boss Design and Production Contract

**Author:** Manus AI
**Engine target:** Godot 4.7.2
**Biome:** Lava Fields (`lava`)
**Runtime kind:** `kilnheart_colossus`

## Encounter identity

The **Kilnheart Colossus** is a colossal six-legged forge beast assembled from interlocking obsidian plates around a visible molten core. It is not a reskinned sandworm: the creature remains above ground, advances with heavy articulated steps, braces before attacks, and changes silhouette as its shell fractures. Its broad low stance, crown-like furnace vents, glowing core, and asymmetrical basalt crusher claws distinguish it from the smaller Cinder Crawler and Ember Skitter.

The Colossus is exclusive to the Lava Fields. At Alert III, the encounter director may maintain one living volcanic boss after a short grace period. Entering another biome disperses it immediately; returning to lava may respawn it at full health until it is truly defeated. A real defeat persists for the run and awards the existing boss bonus exactly once.

| Contract | Value |
|---|---:|
| Maximum health | 18 |
| Forge Sweep damage | 10 |
| Magma Ram damage | 14 |
| Caldera Barrage damage | 6 per pulse |
| Armor stages | 3 |
| Visible locomotion | Six-legged surface walk with asynchronous body bob |
| Spawn rule | Lava biome, Alert III, one living Colossus |
| Sanctuary rule | Cancel unresolved attacks and disperse |
| Reward | Existing enemy reward plus two boss bonus drops |

## Armor phases and animation states

Armor stage is derived from health so large simulation deltas, save/replay, and test setup cannot desynchronize behavior. A threshold crossing cancels unresolved damage, plays the fracture state once, and opens a bounded damage window.

| Stage | Health | Visual state | Behavior |
|---|---:|---|---|
| **Sealed Kiln** | 18–13 | Intact shell, narrow orange seams | Deliberate movement and the wide **Forge Sweep** |
| **Cracked Crucible** | 12–7 | Split plates, brighter core | Faster movement and the committed **Magma Ram** lane |
| **Core Breach** | 6–1 | Broken crown, exposed white-orange furnace | Fast cadence and three-pulse **Caldera Barrage** |

The sprite set contains eight standalone 512×512 runtime assets prepared from GPT Image 2 masters. `idle` is the stable body reference. Two alternating `walk` frames create a readable six-leg gait. `windup` lowers the shell and brightens the furnace before every committed attack. `attack` extends the crusher claws and opens the vents. `cracked` and `broken` replace the body at health thresholds. `defeat` collapses the creature into cooling plates while runtime fade and debris remain code-driven.

| Runtime asset | Purpose |
|---|---|
| `kilnheart_idle.png` | Intact neutral/readiness pose |
| `kilnheart_walk_a.png` | Front-left and rear-right legs planted |
| `kilnheart_walk_b.png` | Opposite tripod planted |
| `kilnheart_windup.png` | Low brace, core compressed and bright |
| `kilnheart_attack.png` | Crusher claws extended, furnace vents open |
| `kilnheart_cracked.png` | Stage-one split armor |
| `kilnheart_broken.png` | Stage-two exposed core and missing crown plates |
| `kilnheart_defeat.png` | Collapsed cooling shell |

## Custom attack patterns

Every pattern commits its geometry when the warning begins. Player movement after commitment changes only whether the final geometric test hits. Each serial and pulse resolves once. Sanctuary entry and biome exit cancel all unresolved damage.

| Pattern | Phase | Telegraph | Resolution | Counterplay |
|---|---|---|---|---|
| **Forge Sweep** | Rotating cycle | A 110-degree amber fan anchored at the boss, with radial heat boundaries | One 10-damage pulse if the Walker remains inside the committed fan and range | Move behind the boss or leave the fan radius |
| **Magma Ram** | Rotating cycle | A narrow molten lane from the boss through an overshot target; cyan side rails show safety | The Colossus charges to lane end and deals one 14-damage pulse along the segment | Move perpendicular beyond either side rail |
| **Caldera Barrage** | Rotating cycle | Three committed eruption circles around the captured position with ordered countdown rings | Three timed 6-damage pulses; each circle resolves once during the attack state | Weave between circles as their countdowns complete |

## Runtime architecture

`kilnheart_boss.gd` owns deterministic phase thresholds, timings, target construction, geometric hit tests, and entity creation. `kilnheart_visuals.gd` owns texture selection, walk-frame timing, scale, and draw metadata. `worm_telegraph.gd` receives snapshots and renders warnings without mutating combat. The existing `sandworms.gd` enemy owner delegates boss behavior through a small boss-kind adapter instead of growing a second full state machine inside its 1,000-line file.

The encounter director chooses a boss kind from the active biome: `ironjaw_apex` in desert and `kilnheart_colossus` in lava. Wetland and frozen biomes do not spawn bosses in this change. Separate per-kind defeated flags prevent one boss defeat from suppressing the other.

## Acceptance criteria

The implementation is complete when the Colossus spawns only in Lava Fields at Alert III, all three attacks use committed deterministic geometry, damage cannot duplicate, sanctuary and biome exit cancel attacks, all eight GPT Image 2 textures load with clean alpha, walk and attack states visibly animate, phase textures change at twelve and six health, its health bar and hover dossier are distinct from the desert Apex, specialized movement and attack SFX route through the Enemy bus, the Web export includes every sprite and sound, and headless plus Xvfb validation passes on the synchronized `main` branch.

## Generated sprite review notes

The idle master has a strong boss-scale silhouette, readable six-legged anatomy, clear asymmetrical claws, and a bright central core. GPT Image 2 left green key-color streaks across the alpha area, so the deterministic preparation stage must remove connected green pixels and dark teal background remnants before downsampling. Walk frame A preserves identity and framing but uses a nearly opaque dark teal background; its leg shift is subtle enough for a two-frame gait when combined with runtime body bob and alternating cadence. Both subjects remain fully inside the canvas with ample cleanup margin.

Walk frame B remains visually consistent and supplies the opposite body height and leg spacing needed for an alternating gait, though green fringe and dark teal background remain around the silhouette. The windup frame reads clearly through the lowered shell, inward claws, and fully lit vent mouths; it is sufficiently different from idle for a warning animation. Both can be cleaned through background-connected segmentation because the foreground retains high local contrast and no intentional teal backdrop detail is required.

The attack frame opens the vents and pushes both claws forward, giving the release a distinct silhouette and brighter core. The cracked frame clearly communicates the first armor threshold through widened orange seams and damaged vent crowns while preserving the full six-legged stance. Both retain the dark teal opaque generation background and minor green edge spill, but their foregrounds are cleanly separable and remain fully inside the frame.

The broken-state master exposes a dramatically brighter core and missing crown sections while retaining a combat-ready silhouette. The defeat master drops the body height, folds the legs and claws inward, and cools the core to amber, making it clearly distinct from both idle and active damage phases. All eight masters are accepted for deterministic background segmentation, common-foot alignment, and 512×512 runtime preparation.

The prepared 512×512 runtime set has clean transparent silhouettes, a common ground contact at y=478, and strong small-scale readability. Walk A and Walk B alternate body height and leg spacing; Windup crouches and opens the vents; Attack raises the forebody; Cracked and Broken increase core exposure; Defeat is visibly lower and cooled. No green or dark-teal background remnants are visible in the gameplay-scale preview.

## Final visual certification

A windowed 1600 × 900 Xvfb capture under Godot 4.7.2 verified the shipped renderer rather than a mock image. All eight GPT Image 2 states remain readable at gameplay scale: the alternating walk poses preserve identity, the compressed windup and extended attack pose separate warning from release, cracked and broken armor expose progressively hotter core damage, and the defeat sprite lies clearly grounded. Feet remain aligned across standing states, silhouettes are not clipped, transparent edges are clean, and health-threshold markers remain legible.

The same capture exercised the real Kilnheart telegraph helper. Forge Sweep presents a broad amber fan, Magma Ram presents a narrow cyan-edged charge lane with a dashed molten centerline, and Caldera Barrage presents three ordered eruption circles. Countdown arcs and the source marker remain visible without obscuring the boss or implying collision outside the committed damage geometry.
