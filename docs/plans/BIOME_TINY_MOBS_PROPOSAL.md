# Biome-Specific Tiny Mob Proposal

**Author:** Manus AI

**Project:** Proto Isometric / Walker's Wake
**Scope:** Replace the single cross-biome Razor Mite presentation with one tiny hostile mob native to each playable biome.

## Design direction

The tiny enemies remain the game’s **fast, one-hit swarm pressure layer**. They share the proven encirclement, warning, attack-cooldown, sanctuary, targeting, and population-cap systems, but each biome receives a distinct creature identity, silhouette, sprite, label, palette, and modest movement/attack tuning. This keeps the system readable and maintainable while removing the impression that a desert scarab has been copied into every environment.

Each sprite will be an original **GPT Image 2** asset on a transparent 512 × 512 RGBA canvas. The art direction matches the existing hostile-fauna library: three-quarter isometric view facing down-right, biome-weathered organic-mechanical anatomy, dark joint structure, restrained emissive accents, no text, no scenery, no cast shadow, and a complete centered silhouette. Because these mobs render much smaller than major fauna, every design emphasizes one dominant silhouette feature and avoids fragile micro-detail.

## Proposed mob roster

| Biome | Mob | Appearance | Readable silhouette | Combat identity |
|---|---|---|---|---|
| **Desert** | **Glassback Scarab** (`glassback_scarab`) | A tiny six-legged desert beetle with overlapping ochre-and-rust armor, a translucent amber glass carapace, black iron joints, two shovel-like mandibles, and a small hot-gold eye slit. Sand has abraded the shell edges to pale cream. | Broad oval back, forward forked mandibles, low stance. | Baseline swarm unit: balanced speed, short warning, 2 damage. This is the evolved native version of the current desert scarab concept. |
| **Oasis Wetlands** | **Mire Tick** (`mire_tick`) | A squat marsh parasite with a dark teal seed-pod abdomen, six thin mud-caked legs, a circular lamprey-like mouth beneath the front plate, short reed whiskers, patches of moss, and two dim cyan sensory nodes. | Round pod body, splayed needle legs, reed whiskers. | Slower but stickier encirclement: slightly tighter orbit and a longer warning, 2 damage. |
| **Frozen Tundra** | **Rime Shardling** (`rime_shardling`) | A tiny four-legged ice arthropod with chipped white ceramic armor, a dark mechanical core, three large translucent blue crystal spines, hooked skating claws, and a narrow cyan eye slit. Frost dust rims the plates. | Triangular crystal crown, four hooked legs, pointed front. | Fast flanker: highest movement speed, wider orbit, slightly longer recovery, 2 damage. |
| **Lava Fields** | **Ember Skitter** (`ember_skitter`) | A compact six-legged obsidian crawler with cracked basalt plates, glowing orange magma seams, two short furnace-horn vents, black hooked feet, and a bright ember mouth. A few cooled ash flakes cling to its back. | Angular black shell, twin vents, incandescent cracks. | Heavy swarm bite: slightly slower approach and longer warning, but 3 damage. |

## Gameplay tuning

| Mob | Move speed | Orbit radius | Warning | Recovery | Damage | Health |
|---|---:|---:|---:|---:|---:|---:|
| Glassback Scarab | 1.46 | 0.82 | 0.44 s | 0.58 s | 2 | 1 |
| Mire Tick | 1.30 | 0.74 | 0.52 s | 0.54 s | 2 | 1 |
| Rime Shardling | 1.62 | 0.94 | 0.46 s | 0.68 s | 2 | 1 |
| Ember Skitter | 1.34 | 0.84 | 0.58 s | 0.72 s | 3 | 1 |

All four variants retain the existing hard cap of twelve simultaneous tiny mobs and the shared 0.62-second damage token, preventing pack-size burst damage. Every mob remains destructible by one accepted Impact hit. The attack state machine and targeting contract stay shared; per-kind values are selected from a deterministic catalog.

## Sprite production specification

| Requirement | Specification |
|---|---|
| Generation model | GPT Image 2 |
| Deliverables | Four standalone PNG files, one per mob |
| Runtime canvas | 512 × 512 pixels, RGBA |
| Background | True transparency; no key color in the final derivative |
| View | Three-quarter isometric, facing down-right |
| Framing | Full creature visible, centered, approximately 76% canvas occupancy |
| Lighting | Soft upper-left key light, restrained rim light, no ground shadow |
| Readability target | Distinct at 42–48 rendered pixels |
| Style | Painterly pixel-stepped game sprite consistent with existing hostile fauna; simplified material clusters, crisp silhouette |
| Prohibited content | Text, UI, scenery, multiple creatures, weapons, detached parts, cast shadow, border, frame |

## Implementation plan

The implementation will convert `melee_pressure.gd` from a single `KIND` constant into a biome-to-kind catalog. `Sandworms` will propagate the active biome into `MeleePressure`; every spawned mob will store its kind, and combat snapshots, hover targets, damage signals, labels, and sprite selection will derive from that stored kind. Biome transitions already clear the existing enemy population, so a new pack cannot retain the previous biome’s identity.

The generated sprites will live under `assets/enemies/tiny_mobs/`, with provenance and checksums recorded alongside the existing enemy-source documentation. Localization will add English and Simplified Chinese names for all four variants. The Web export resource list will explicitly include the new assets.

## Acceptance criteria

| Area | Acceptance criterion |
|---|---|
| Identity | Each playable biome spawns exactly its assigned tiny-mob kind. |
| Appearance | Each kind renders with its own GPT Image 2 sprite and remains visually distinguishable at gameplay scale. |
| Combat | Existing encirclement, warning, shared damage token, sanctuary dispersal, targeting, one-hit destruction, and pack cap remain operational. |
| UI | Hover cards and damage sources report the correct biome-specific kind and localized name. |
| Transitions | Changing biome clears the old pack; subsequent packs use the new biome’s identity. |
| Assets | Four transparent 512 × 512 runtime PNGs import successfully with no missing-resource errors. |
| Validation | Focused mob tests, full lint/import/smoke/boot validation, and a windowed/Xvfb screenshot check all pass under the pinned Godot version. |
