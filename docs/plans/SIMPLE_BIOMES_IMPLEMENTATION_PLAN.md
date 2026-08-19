# Walker's Wake Simple Biomes Implementation Plan

**Plan status:** Proposed implementation plan; none of the biome work described here is claimed complete.

**Target:** Godot 4.7.1, GL Compatibility, desktop/Web keyboard play, and coarse-pointer/touch parity.

## 1. Scope and simplicity contracts

This plan adds three deterministic terrain biomes to **Walker's Wake** in the order **Oasis / Wetlands**, **Lava Fields**, then **Frozen Tundra**. It follows the approved direction that a biome is a clear change of place with exactly one ground rule, not a new rulebook.[1] Walker keeps the shipped expedition loop, controls, combat vocabulary, enemies, resources, relays, outposts, settlement, responsive layouts, and save model described by the current game and implementation baseline.[2][3]

> **Product promise:** The player enters a visually distinct place, understands its single terrain rule from the ground itself, and continues playing with Drive, Run, and Smash.

| Contract | Required result |
|---|---|
| **One biome, one rule** | Dark mud slows Walker; lava damages Walker while touched; blue ice preserves momentum and reduces steering until snow. No biome receives a second mechanical rule. |
| **No new field verbs** | WASD/arrows, Shift, Space/J/K, the floating joystick, outer-ring run intent, and the single SMASH button remain the complete field vocabulary.[6][7] |
| **Ground is the explanation** | Surface value, pattern, edge shape, and material contrast communicate safe versus special ground. No biome meter, status stack, immunity icon, interaction prompt, or tutorial button is added. |
| **Existing systems remain authoritative** | Projection, collision, diagonal corner checks, Impact Charge, contact-frame Smash, enemies, hazards, relays, outposts, economy, extraction, settlement, and responsive UI retain their current owners and values.[2][3][5] |
| **Generated, not persisted** | Biome and surface IDs are pure functions of coordinates, fixed profile values, and derived objective reservations. Save schema 3 and world-generation version 1 remain unchanged.[4][9] |
| **Bounded streaming** | The world remains an 8×8-cell chunk stream with a 5×5 loaded ring, at most 1,600 active cells, and a 29×29/841-cell render window.[4] No biome creates per-cell Nodes, materials, collision bodies, or travel-distance caches. |
| **Safe objectives** | The protected 18×18 starter remains behaviorally desert. Outpost sanctuaries and any biome-specific objective approach reservation are visibly safe ground, without hidden damage immunity or altered link/service rules. |
| **Roster reuse** | Sandworms, tornadoes, sandstorms, and Alert composition keep identical simulation. A biome may select a palette or particle label only; visual selection cannot change timing, damage, health, hitboxes, spawn quotas, rewards, or state transitions.[16][17][18] |
| **Reversible delivery** | Each public increment is a focused source commit and immutable Web PCK. Rollback is the previous source commit plus previous WebDev pointer; no migration or save rewrite is required because generated surfaces are not stored. |

This plan lands with the launch-briefing release at project version `1.0.7`. Biome implementation begins from that verified `origin/main` baseline and uses the next free patch version. Work remains serial unless a later increment contains genuinely disjoint asset generation; shared hot files are changed by one owner at a time.

## 2. Shared biome foundation

The shared foundation is defined once here and lands as part of **OW-01**, not as a speculative framework-only release. Oasis proves the APIs with the smallest rule; Lava and Frozen extend the same contracts without creating parallel renderers, world stores, input paths, or save fields.

### 2.1 Existing authorities that do not move

`InfiniteWorld` already owns deterministic terrain, signed coordinate hashing, chunk loading and eviction, walkability, outposts, generated scrap, and compact mutation snapshots.[4] `IsometricMap` is the field composition root and already owns the 90×45 projection, 150 px/s walk speed, 1.5× run multiplier, 310 acceleration, 390 deceleration, the 0.05-second movement-step cap, live fractional player position, damage routing, and system wiring.[5] `TerrainRenderer` already draws one projected polygon per visible cell with continuous world-space UVs, tint variation, elevation, and grid lines.[8] Those ownership boundaries remain intact.

The current `InfiniteWorld.terrain_at(cell)` API is the canonical loaded-terrain query and should be extended rather than adding a synonymous `get_terrain` method.[4] New APIs are `biome_at(cell)`, `is_mud(cell)`, `is_lava(cell)`, and `is_blue_ice(cell)`. Pure classification helpers may answer unloaded cells directly, but public gameplay queries must remain bounded and must not implicitly load an entire macro-region.

### 2.2 Exclusive biome resolution

The three source proposals were written as standalone slices and contain one direct conflict: Oasis and Frozen both reserve macro-region `(0,0)`. The combined implementation must resolve that conflict before code is merged. The authoritative showcase assignments for this plan are therefore:

| Biome | Showcase assignment | Reason |
|---|---|---|
| **Oasis / Wetlands** | 64×64 macro-region `(0,0)`, with the existing 18×18 starter excluded | Retains the lowest-risk nearby showcase and the approved first-biome route. |
| **Lava Fields** | 32×32 macro-region `(1,0)`, including the teaching outpost at `(40,10)` and nearby pool | Retains the proposed deterministic lava loop. This forced 32×32 reservation wins over the Oasis candidate for those cells. |
| **Frozen Tundra** | 64×64 macro-region `(0,-1)`, not `(0,0)` | Provides a nearby northern showcase without contradictory biome ownership. Golden tests must lock this normalization. |

A new pure `scripts/biome_resolver.gd` coordinates exclusive ownership. It receives integer cell coordinates and the three classifier/profile objects; it knows no Nodes, input, renderer, save repository, enemies, economy, or mutable RNG. For each cell it first protects starter desert, then applies forced showcase reservations, then evaluates each biome's independent hashed candidacy. When two nonforced candidates overlap, the resolver chooses the candidate with the lowest deterministic salted rank. The rank is calculated from the macro coordinate and biome salt, not from call order. This retains unlimited recurrence while guaranteeing one biome and one special-surface rule per cell.

Biome-specific classifiers retain their own geometry: `oasis_wetlands.gd` owns oval wetlands and mud lenses; `lava_fields_profile.gd` and its pure sampling helpers own lava macro selection and integer value noise; `frozen_tundra_profile.gd` and its pure sampling helpers own frozen selection and lake centers. `BiomeResolver` only chooses ownership. It does not merge surfaces, cache macro objects, or reinterpret biome tuning.

### 2.3 Cell-generation order

Every generated cell follows one fixed order so mutations and authored systems remain stable:

| Order | Operation | Contract |
|---:|---|---|
| 1 | Calculate shipped desert base terrain | Preserve starter relay/rocks, salt/ruin/rock thresholds, generated outpost hash, generated scrap decision inputs, and coordinate bounds.[4] |
| 2 | Resolve exclusive biome | Use floor division for signed macro coordinates, `posmod` for selection, named integer salts, and no RNG/noise object. |
| 3 | Derive ordinary local ground | Only base `sand` or `salt` may become `wetland_sand`, `dark_mud`, `basalt`, `ash`, `lava`, `snow`, or `blue_ice`. Original `rock` and `ruin` identities remain. |
| 4 | Apply safety geometry | Carve firm wetland, basalt/ash, or snow around outposts, relay reservations, biome borders, obstacles, and teaching exits as specified per biome. Safety changes terrain generation only. |
| 5 | Apply durable mutations | A placed rock remains rock. A destroyed native rock reveals the coordinate-derived local ground rather than hard-coded sand. Existing mutation dictionaries and snapshot keys remain unchanged. |
| 6 | Apply outpost override last | Outpost remains `ruin`, elevation 1, unblocked, and registered. No special surface may appear inside its required safety footprint. |
| 7 | Materialize scrap and bounded dictionaries | Generated and dropped scrap use current decisions and registries. Chunk unload erases the same active dictionaries; reload recomputes identical surfaces. |

This order intentionally permits previously unrecorded sand/salt to look different after the content update while preserving all saved rock, scrap, objective, economy, player, and profile state. That compatibility-visible terrain remap belongs in release notes; it does not justify a schema or generation-version bump.

### 2.4 Shared runtime APIs and surface dispatch

`IsometricMap` remains the only gameplay consumer of player-surface effects.[5] It reads the occupied center cell after the current `screen_to_grid` resolution and does not alter projection, facing quantization, keyboard/touch input readers, `_can_transition`, or diagonal corner checks. The shared movement pipeline is:

1. Read the existing keyboard or touch vector and run intent.
2. Quantize facing and test the existing transition/corner authority.
3. Query the exclusive surface under `_robot_grid`.
4. Compute the existing analog walk/run maximum; apply the Oasis multiplier only for `dark_mud`.
5. Pass current velocity, desired velocity, delta, and surface ID through the pure `SurfaceDrive` adapter once Frozen Tundra lands. Normal ground reproduces current acceleration/deceleration exactly; blue ice uses its traction limits.
6. Hard-clamp mud velocity to its reduced maximum, then call the unchanged movement/collision path.
7. Feed actual resulting velocity to DRIVE, Walker animation, camera lead, and Impact Charge.

OW-01 initially implements step 4 directly in `_update_drive_vector`. FT-01 introduces `scripts/surface_drive.gd` and moves the shared velocity calculation into that pure adapter while preserving byte-for-value normal-ground behavior and the existing mud cap. `SurfaceDrive` cannot query `Input`, world state, collision, Smash, saves, Nodes, hazards, or economy.

Lava contact is deliberately separate from movement. `scripts/lava_contact.gd` samples the same live fractional grid position already sent to worms and hazards, resolves the touched cell by rounded center, and emits `damage_tick(amount, &"lava")`. `IsometricMap` routes that signal through `_apply_chassis_damage`, reusing chassis persistence, shutdown, audio, sparks, and status feedback. Lava neither blocks nor changes velocity.

### 2.5 Shared files and ownership

| File or area | Shared change, made once | Later biome extension |
|---|---|---|
| `scripts/biome_resolver.gd` | Add the pure exclusive selector and forced-anchor precedence in OW-01. | Register Lava and Frozen profiles and deterministic candidate ranking; no gameplay behavior. |
| `scripts/infinite_world.gd` | Split base classification from derived local ground; add `biome_at` and preserve bounded generation/snapshot behavior. | Add biome-specific surface helpers, safe-objective reservations, rock-reveal ground, and predicates. |
| `scripts/isometric_map.gd` | Register surface textures and query occupied terrain without changing input/projection. | Add `LavaContact`, then `SurfaceDrive`; keep this script orchestration-only. |
| `scripts/terrain_renderer.gd` | Generalize the existing color/texture switch for named surfaces and deterministic fallbacks. | Add each biome's colors, patterns, and textures through the same polygon/UV path. |
| `scripts/visual_catalog.gd` | Extend required runtime paths for accepted terrain PNGs.[13] | Append each biome's accepted files; keep gameplay independent of load success. |
| `assets/textures/terrain/SOURCES.md` | Create one cumulative provenance file for all generated terrain derivatives. | Append tool, prompt summary, date, deterministic processing, dimensions, SHA-256, and rights note for each accepted PNG. |
| `test/test_contracts.gd` | Register biome-focused suites in the existing contract aggregator.[21] | Append one suite per biome without weakening existing cases. |
| `test/smoke.gd` | Add only scene-level integration checks not expressible in pure suites. | Cover occupied-surface behavior, save reconstruction, touch parity, and assets. |
| `export_presets.cfg` | Keep Web, GL Compatibility, no threads/PWA, output path, and terrain PNG wildcard unchanged.[19] | Add new standalone scripts and `.tres` resources to the explicit resource list when dependency closure does not already include them; never broaden export to test/docs. |
| `project.godot` | No engine, renderer, viewport, input, or filter changes. | Bump one patch per public increment using the next free release-time version. |

No biome scene is added. `scenes/isometric_map.tscn` remains unchanged unless an engine limitation proves runtime construction impossible; that exception requires a separately reviewed plan change.

### 2.6 Shared assets and visual language

All shipping terrain plates are optimized 512×512 repeatable PNGs. Generate independent top-down material candidates with GPT Image 2, then deterministically remove borders, offset-check seams, downscale, limit high-frequency noise, and inspect 3×3 repetition at the shipped 90×45 tile projection. Keep only runtime derivatives in Git and record hashes and processing in the shared `SOURCES.md`. Existing world-space UVs and texture repeat remain authoritative.[8]

Every special surface must remain distinguishable in grayscale and at responsive zoom 0.65. Mud uses dark value plus broad wet sheen; lava uses a bright core, dark crust, and rim/crack silhouette; blue ice uses long grain and subsurface cracks against broad matte snow. Color reinforces, but never solely carries, the rule. Missing textures fall back to deterministic renderer colors/patterns and may not alter simulation.

### 2.7 Shared save, streaming, and release contracts

SaveRepository remains format 3 with the exact top-level keys `save_format_version`, `metadata`, `world`, `active_run`, and `profile`; its validator rejects unknown keys.[9] `WORLD_GENERATION_VERSION` remains 1. InfiniteWorld snapshots remain only `destroyed_rocks`, `placed_rocks`, `dropped_scrap`, and `collected_scrap` inside the existing world payload.[4] No biome, surface, contact timer, traction value, velocity, palette, loaded chunk, or procedural cache is serialized.

Schema-1/2 migration, primary/backup selection, atomic temporary replacement, quarantine, future-save write blocking, and strict bounds remain unedited and must pass their existing suites.[9][10] Loading restores player/run/profile/mutations first, streams the current chunks, then deterministically reconstructs the occupied surface. Mud applies on the first movement frame. Lava contact begins only after ready and uses fresh entry semantics. Blue-ice velocity remains transient and resumes at zero, matching current save behavior.

Every public increment uses one shared release gate. Run focused tests while iterating, then run exactly one clean full command, `./verify.sh --release`, which imports, lints, runs smoke/contracts, boots, recreates the Web directory, rejects test/addon/provenance/artifact leakage, and requires nonempty HTML/JS/WASM/PCK outputs.[20] Record the fresh PCK SHA-256 and byte size, upload it under an immutable version-and-source-specific name, update only the WebDev wrapper's `MAIN_PACK` URL and exact size, run its check/build, publish, and perform cache-busted 1280×720 and 390×844 public smokes. The public bundle must request that exact PCK and report no console, network, CSP, missing-resource, or WebGL errors. Only then push the matching source commit and require source/WebDev worktrees clean. This is a delivery gate, not a new evidence subsystem.

## 3. Dependency and implementation order

| Order | Dependency | Why it precedes the next step | Output |
|---:|---|---|---|
| 1 | **Oasis / Wetlands** plus shared resolver | Lowest-risk speed cap proves exclusive classification, generated surfaces, renderer extension, assets, occupied-cell lookup, saves, streaming, mobile, and Web deployment. | OW-01 public vertical slice and reusable shared foundation. |
| 2 | **Lava Fields** contact rule | Reuses the proven resolver/renderer and existing chassis-damage path; adds objective-safe damaging terrain without touching movement. | LF-01 playable teaching loop. |
| 3 | Lava safety/visual certification | Relay reservations and palette-only treatment depend on stable lava generation/contact. | LF-02 release-complete Lava Fields. |
| 4 | **Frozen Tundra** traction rule | Highest movement risk comes last, after surface ownership, safe routes, keyboard/touch regression, and Web profiling are proven. | FT-01 playable traction slice with procedural fallback. |
| 5 | Frozen art certification | Accepted textures replace, but do not remove, the deterministic fallback. | FT-02 release-complete Frozen Tundra. |

## 4. Milestones

| Milestone | Goal | Affected area | Done condition |
|---|---|---|---|
| **OW-01** | Ship the shared resolver and one complete Oasis rule slice. | Resolver, Oasis classifier, InfiniteWorld, map movement cap, renderer, balance, two textures, tests, Web release. | Mud is readable and caps actual walk/run speed only while occupied; starter, safety, systems, schema, bounds, desktop/touch, and public build are clean. |
| **LF-01** | Ship deterministic basalt/ash/lava and continuous lava contact in a short safe loop. | Lava profile, InfiniteWorld, LavaContact, map damage wiring, renderer/fallbacks, teaching outpost/pool, tests. | Entry deals 8 immediately, repeat cadence is 1 second, exit stops damage, movement/Smash remain baseline, and the forced loop has two safe exits. |
| **LF-02** | Complete lava objective safety, assets, optional palette treatment, and soak. | Relay reservations, rock reveal, three textures, VisualCatalog, palette-only adapters, export, long traversal tests. | Outpost/relay footprints are lava-free, assets/readability pass, roster logic snapshots are identical, bounds/performance hold, and the public immutable PCK is verified. |
| **FT-01** | Ship deterministic snow/blue ice and pure traction behavior with fallbacks. | Frozen profile, resolver, InfiniteWorld, SurfaceDrive, map orchestration, renderer fallbacks, relay/outpost safety, tests. | Blue ice coasts and turns less than snow; snow exactly restores baseline traction; all controls/collision/systems/save/bounds remain clean. |
| **FT-02** | Add accepted Frozen runtime art and final cross-biome certification. | Two textures, shared provenance, VisualCatalog, asset/export tests, public device matrix. | Snow and ice remain distinct in color and grayscale at 0.65 zoom, fallbacks remain playable, all three biome rules coexist exclusively, and the cross-biome gate passes. |

## 5. Oasis / Wetlands

### 5.1 Player promise and smallest playable increment

> **Player promise:** Dark mud slows Walker while the occupied center cell is mud; every other wetland surface and every existing action follow shipped rules.

OW-01 is one complete vertical slice, not a precursor framework commit. It contains a guaranteed nearby wetland outside the unchanged starter, connected firm wetland ground, three readable mud lenses with at least a two-cell firm bypass, a visibly firm outpost sanctuary, accepted wetland/mud textures, and the occupied-cell speed cap. Existing worms and weather remain present and mechanically unchanged. The player can choose the slower shortcut or drive around it with no new UI.

### 5.2 Architecture, files, data, and assets

| File | Concrete change |
|---|---|
| `scripts/oasis_wetlands.gd` | Add a stateless classifier exposing oval membership, `surface_for(cell, base_terrain, safety)`, and `is_mud(surface)`. It depends only on integer coordinates/math and named constants. |
| `scripts/biome_resolver.gd` | Add exclusive selection with protected starter, forced Oasis anchor, reserved Lava anchor, named salts, and order-independent overlap rank. |
| `scripts/infinite_world.gd` | Derive wetland only from base sand/salt; preserve rock/ruin/outpost/scrap/mutations; add `biome_at` and `is_mud`; carve the existing 2.5-cell sanctuary to firm wetland. |
| `scripts/isometric_map.gd` | Preload/register two textures; sample `_robot_grid`; apply the balance multiplier to the existing analog walk/run maximum; hard-clamp current velocity after acceleration. Do not change controls, facing, projection, collision, or Smash. |
| `scripts/terrain_renderer.gd` | Add `wetland_sand` and `dark_mud` colors/textures and a deterministic dark wet-pattern fallback through the current polygon/UV path. |
| `scripts/balance_profile.gd`, `data/balance/default_balance.tres` | Add validated `mud_speed_multiplier`, default 0.62, legal range 0.45–0.85, and include it in the baseline snapshot.[11][12] |
| `scripts/visual_catalog.gd` | Require the two accepted runtime texture paths.[13] |
| `assets/textures/terrain/oasis_wetland.png`, `dark_mud.png` | Add seamless 512×512 runtime derivatives. Wetland is pale warm sand with restrained shallow-water traces; mud is brown-black with broad sheen and irregular edge flecks. |
| `assets/textures/terrain/SOURCES.md` | Create the shared terrain provenance file with prompt summary, tool/date, processing, dimensions, SHA-256, and rights note. |
| `test/test_oasis_wetlands.gd` | Add deterministic generation, topology, sanctuary, streaming, movement, and save reconstruction cases. |
| `test/test_balance.gd`, `test/test_contracts.gd`, `test/smoke.gd` | Validate tuning/range, register focused cases, and add scene-level keyboard/touch/asset/save integration without weakening existing assertions. |

### 5.3 Deterministic world generation

Floor-divide signed cells into 64×64 macro-regions. Region `(0,0)` is an Oasis candidate, but cells inside the current 18×18 starter and the forced Lava 32×32 reservation are excluded. Other regions become candidates when `posmod(hash(region, OASIS_REGION_SALT), 4) == 0`, subject to the shared exclusive resolver.

For each selected region, salted hashes derive center jitter of ±8 cells, x radius 18–22, and y radius 12–16. Cells inside that oval map eligible base sand/salt to `wetland_sand`. Three mud lenses lie near major-axis offsets −9, 0, and +9; each receives a hashed y offset of ±4, x radius 5–7, and y radius 3–5. Original rock and ruin interrupt the surface without changing identity. Any cell within the existing outpost sanctuary radius 2.5 is firm `wetland_sand`; the outpost itself is still the final `ruin` override. No FastNoiseLite, RNG state, region object, or finite map allocation is permitted.

### 5.4 Rule integration

At the beginning of the existing drive update, calculate the normal analog maximum of 150 walk or 225 run and multiply it by 0.62 only when `terrain_at(_robot_grid) == &"dark_mud"`. Move toward the desired velocity with existing acceleration, then clamp velocity length to that surface maximum. Entry becomes legible on the first frame after the center occupies mud and carried run momentum cannot cross the patch above the mud cap. Exit retains mud behavior until the center occupies firm ground, then recovers with existing acceleration.

The result is isotropic: N, NE, E, SE, S, SW, W, and NW preserve direction and normalized diagonal speed. Actual velocity continues to drive animation, camera lead, DRIVE percentage, and Impact Charge. Mud does not add a timer, stack, stamina cost, damage, enemy modifier, collision rule, placement restriction, immunity, save field, or economy interaction.

### 5.5 Enemy visual treatment

OW-01 leaves existing worm, tornado, sandstorm, and atmosphere logic and art adapters unchanged. A later separately approved visual-only patch may select muddy wake colors or mist/reed hues, but no enemy reskin is required for acceptance and no classifier dependency may enter enemy state machines. Palms, reed props, particles, audio, and new enemy atlases are excluded from this increment.

### 5.6 Save/load and streaming

A save on mud restores the same player cell, facing, run/profile, and world deltas; chunk generation reconstructs `dark_mud`, and the multiplier applies on the first movement frame. No occupancy state is saved. Existing unrecorded sand/salt may become wetland after update, but valid cells remain walkable and all rock/ruin/outpost/objective/economy identities remain stable.

Travel tests cross at least 64 macro boundaries and approach coordinates ±999,900. The loaded ring remains exactly 25 chunks, active terrain remains at most 1,600 cells, visible cells remain within `(14,14)` and sorted by existing isometric order, and unloading removes all active dictionaries. Revisit and shuffled generation order must reproduce golden surfaces.

### 5.7 Accessibility and mobile

Mud must be darker and texturally broader than wetland, not merely greener or browner. Validate normal color, grayscale, and common color-vision simulations at 90×45 tiles, desktop landscape, tablet landscape, and native 390×844 portrait with camera zoom at least 0.65.[14][15] Existing HUD, joystick exclusion rectangles, left-handed mirror, outer-ring hysteresis, haptics, and SMASH placement remain authoritative.[7]

Touch vectors pass through the same occupied-surface speed cap as keyboard vectors. Dead-zone input remains zero, mid-radius magnitude remains proportional, run hysteresis remains 0.88/0.72, release clears input, and SMASH emits once. No mud haptic pattern or status icon is added.

### 5.8 Focused test matrix

| Area | Required focused coverage |
|---|---|
| Generation | Golden positive, negative, `-1/-64/-65`, macro-edge, starter, firm, mud, rock, ruin, and outpost cells; forced anchor contains firm and mud outside starter; shuffled generation and unload/reload agree. |
| Shape and safety | Selected samples have connected firm ground, at least one coherent mud lens, 20–30% mud among Oasis walkable cells, a two-cell firm bypass, and no mud within sanctuary radius 2.5. |
| Keyboard | All eight directions at walk/run preserve facing and 2:1 displacement signs; firm reaches 150/225, mud reaches 93/139.5 within tolerance; diagonals are normalized; high-speed entry clamps immediately; corner blocking is unchanged. |
| Touch | Dead zone, mid strength, outer-ring enter/exit, release, reacquire, left-handed layout, exclusions, and simultaneous SMASH use the same scalar-only slowdown. |
| Save | Existing schema-1/2 and schema-3 primary/backup/corrupt/future cases pass; mud-cell round trip adds no envelope/world keys and rotates a subsequent save normally. |
| Systems | Complete a three-relay expedition through Oasis, collect rewards, Smash a rock and worm, survive existing weather, use sanctuary/repair/Refit, extract/settle, and reload with unchanged costs, rewards, timings, quotas, and attack frame 11.[24] |
| Assets/export | Both PNGs load as nonempty 512×512 textures, catalog validation passes, repeat remains enabled, fallback does not change simulation, and the clean release closes all resources. |

### 5.9 Performance budget

Initial 25-chunk generation must remain below 5 ms median and one 8×8 chunk below 1 ms median on the reference machine. A fixed 600-frame route uses the existing bounded sampler and may not worsen p95 by more than 10% from the clean baseline.[23] There are no per-cell Nodes/materials, no macro cache, no repeated full classifier scan in `_process`, and no dictionary growth with travel. Occupied-surface lookup may run per drive frame; procedural classification runs when a cell is generated, not once per draw call.

### 5.10 Tuning defaults

| Setting | Default |
|---|---:|
| Mud speed multiplier | `0.62` (legal `0.45–0.85`) |
| Firm walk/run | `150 / 225 px/s` |
| Mud walk/run cap | `93 / 139.5 px/s` |
| Macro-region | `64×64` cells |
| Additional candidate frequency | `1 in 4` |
| Oval center jitter | `±8` cells |
| Oval radii | `x 18–22`, `y 12–16` |
| Mud lenses | `3`, x offsets `−9/0/+9`, y jitter `±4` |
| Lens radii | `x 5–7`, `y 3–5` |
| Target mud share | `20–30%` of walkable Oasis cells |
| Sanctuary clearance | Existing `2.5` cells |

### 5.11 Rollback and done condition

Rollback reverts the OW-01 source commit and restores the previous immutable WebDev PCK pointer. Because schema and world snapshots never contain biome fields, existing saves need no downgrade transform. If the shared resolver, starter preservation, or old-save tests fail, rollback the whole vertical slice rather than retaining dormant biome framework.

**OW-01 is done** when a clean public build can start or reload legacy/schema-3 runs, reach recurring Oasis terrain, distinguish firm wetland from mud without UI, and cap Walker to 62% of the same walk/run vector only while the occupied cell is mud across keyboard and touch. Projection, collision, Smash, charge, enemies, hazards, relays, outposts and 2.5-cell firm sanctuary, economy, settlement, portrait layout, streaming/culling, save behavior, focused tests, release export, immutable PCK verification, matching pushed source, and clean worktrees must all pass.

## 6. Lava Fields

### 6.1 Player promise and smallest playable increment

> **Player promise:** Touching lava deals continuous chassis damage; basalt, ash, rocks, ruins, objectives, and all controls otherwise follow shipped rules.

LF-01 is a short deterministic loop around one highly visible lava pool in forced 32×32 region `(1,0)`. It includes the existing-system outpost at `(40,10)`, a pool near `(45,10)`, a basalt return loop at least two cells wide, and two obvious exits. Lava is walkable and never Smashable. Entry damage reuses the existing chassis path; no heat meter, burn stack, immunity, resistance module, new resource, or new interaction is introduced.

LF-02 completes relay/outpost safety, biome-aware rock reveal, accepted textures, optional palette-only enemy/weather treatment, and positive/negative traversal soak. The split keeps contact correctness reviewable before presentation polish while reusing the same shared release gate.

### 6.2 Architecture, files, data, and assets

| File | Concrete change |
|---|---|
| `scripts/lava_fields_profile.gd`, `data/biomes/lava_fields.tres` | Add a validated data-only profile for 32-cell macros, salts, teaching cells, 8-cell lattice, threshold, border, safety margins, damage 8, and cadence 1.0 second. |
| `scripts/biome_resolver.gd` | Register the forced `(1,0)` 32-cell reservation and 1-in-5 hashed candidacy with exclusive deterministic ranking. |
| `scripts/infinite_world.gd` | Generate basalt/ash/lava from eligible ground; expose `is_lava`; add sorted/deduplicated transient safe-objective reservations; ensure destroyed volcanic rocks reveal local safe ground; preserve mutation snapshots. |
| `scripts/lava_contact.gd` | Add a small controller with `configure`, `set_player_position`, `advance`, `reset_contact`, and `damage_tick`. It owns only contact cadence. |
| `scripts/isometric_map.gd` | Construct/configure contact after streaming, feed the existing live fractional position, route damage to `_apply_chassis_damage(amount, &"lava")`, reset on shutdown/place, and update visual biome labels only when biome changes. |
| `scripts/terrain_renderer.gd` | Add `basalt`, `ash`, and `lava` colors/textures; use deterministic bright rim/crack fallback through the existing draw path. |
| `scripts/desert_atmosphere.gd`, `scripts/desert_hazards.gd`, `scripts/sandworms.gd` | LF-02 may add `set_visual_biome` palette selection only. Simulation branches, constants, hit geometry, timers, quotas, rewards, and states must remain identical. |
| `assets/textures/terrain/lava_basalt.png`, `lava_flow.png`, `volcanic_ash.png` | Add seamless 512×512 RGB derivatives: matte charcoal slabs, red-orange/yellow lava with dark crust, and pale low-frequency ash. |
| `scripts/visual_catalog.gd`, `test/test_visual_catalog.gd` | Require each accepted texture and validate exact 512×512 dimensions. |
| `test/test_lava_fields.gd`, `test/test_contracts.gd`, `test/smoke.gd` | Add pure generation/contact/safety/determinism/bounds tests and scene-level damage, controls, save, portrait, and system regression. |
| `export_presets.cfg` | Add new scripts/profile resource to the explicit shipping list if needed; preserve the existing terrain wildcard and Web settings.[19] |

### 6.3 Deterministic world generation

Floor-divide cells into 32×32 Lava macro-regions. Preserve the 18×18 starter. Force `(1,0)` and select other candidates when `posmod(hash(region, LAVA_REGION_SALT), 5) == 0`, subject to exclusive resolution. In a Lava region, original rock/ruin remain; ordinary sand/salt becomes basalt or ash, while lava is derived by integer bilinear value noise on an 8-cell lattice. A deterministic 3×3 neighbor-majority check removes isolated one-cell lava, and a two-cell macro border remains safe basalt/ash.

The teaching pool near `(45,10)` is a fixed deterministic surface override inside the forced region, followed by safety carving. Any cell whose tile footprint intersects an outpost sanctuary is safe ground, using the shipped radius 2.5 plus a 0.5-cell generation margin for visual coverage. Relay reservations come from canonical persisted objective cells after run configure/restore. `set_safe_objectives(cells)` sorts and deduplicates them, and only when the set changes does it clear/restream the active 25 chunks. Reservation geometry is derived, not separately serialized.

Lava is never entered into `_blocked` or `_rocks`. Placed rocks retain current semantics. Breaking a native volcanic rock reveals the safe local basalt/ash derivation, not lava and not hard-coded sand. Generated scrap, pickup placement, objective rewards, costs, and service eligibility remain unchanged.

### 6.4 Rule integration and contact cadence

`LavaContact` samples the same fractional player grid position already calculated for hazards and worms, then rounds to the touched center cell. Entry emits exactly 8 damage immediately. Remaining contact accumulates time and emits 8 at each 1.0-second boundary. A bounded loop handles a large delta; exit resets the accumulator; re-entry emits a fresh entry tick. Shutdown sentinel/zero chassis suppresses further ticks.

Damage travels through `_apply_chassis_damage(amount, &"lava")`, so existing feedback, saving, chassis floor, shutdown, repair, and terminal flow remain authoritative. `module_effects.gd` is not changed; Storm Seal continues to affect only its current weather sources. Contact does not alter acceleration, run speed, Impact Charge, Smash, enemy movement, or sanctuary combat suppression. Sanctuary safety comes from no lava being generated there, not from hidden immunity.

### 6.5 Enemy visual treatment without logic changes

LF-01 may ship with the existing roster art. LF-02 may select an obsidian shell/wake palette for worms, ash-and-ember colors for tornadoes, an ash-front palette for broad storms, and sparse bounded ember atmosphere. Selection occurs when Walker's resolved biome changes, not per enemy decision. Tests snapshot worm health 4, attack 10, FSM/timing/reward/caps, tornado 6 DPS/formation/lifetime, sandstorm 3 DPS/footprint, Alert compositions, and sanctuary behavior before and after palette switching. Any gameplay difference blocks the visual treatment; removing the treatment must leave the biome fully playable.

### 6.6 Save/load and streaming

No lava cell list, contact timer, palette, or reservation copy enters schema 3. Objective reservations are re-derived from canonical `active_run.relay_objectives` before the first visible frame. On reload in Lava Fields, terrain is reconstructed before contact begins; persisted chassis is restored, and contact uses fresh entry semantics only after ready. A save after lava damage and rock mutation must preserve exact player, chassis, mutation, objective, module, economy, profile, backup, and write-sequence behavior.

A soak crosses at least 100 positive and negative macro-regions and revisits evicted cells. It requires exactly 25 loaded chunks, at most 1,600 active cells, at most 841 visible/sorted cells, no retained lava cache, no per-cell Nodes, bounded save size, and identical surfaces after reload/restream. Safe-objective reservation changes invalidate only the active bounded cache.

### 6.7 Accessibility and mobile

Lava must remain identifiable without hue through high luminance, dark crust fissures, and a clear inner rim; basalt and ash remain quieter. Inspect grayscale/high-contrast views at 1280×720, 844×390, and 390×844 with storms, telegraphs, Walker, sanctuary rings, joystick, and SMASH present. Escape lanes cannot be hidden by UI or bright overdraw.

Keyboard and touch use unchanged movement. Contact cadence is independent of analog strength. Tests cover shallow/full touch vectors, outer-ring run, release/coast over an edge, exclusions, left-handed mirror, and simultaneous SMASH. No warning meter, lava button, custom haptic loop, or alternate control appears.

### 6.8 Focused test matrix

| Area | Required focused coverage |
|---|---|
| Generation | Starter golden cells remain desert; forced `(1,0)` returns fixed basalt/lava samples; negative samples, macro edges, shuffled order, restream, and restart agree; lava is walkable; rock/ruin/outpost overrides win. |
| Topology/safety | Teaching loop has two exits and a two-cell basalt path; target lava is 20–30%; macro border is two cells safe; no lava intersects outpost sanctuary or relay radius/margin. |
| Contact | Entry `8`; `0.99 s` no repeat; crossing `1.0 s` one repeat; `2.2 s` two bounded repeats; exit stops; re-entry ticks; safe surfaces never tick; shutdown suppresses ticks. |
| Gameplay | All eight directions remain 150/225 with current acceleration/coast/corners; lava cannot be Smashed; rock Smash still drops two scrap; status uses existing damage path; charge and attack frame remain unchanged. |
| Touch/responsive | Shallow/full vectors, 0.28 quantization, run hysteresis, release, SMASH exclusion, left-handed layout, 1280×720, 844×390, and 390×844 all escape the pool safely. |
| Systems | Complete relays, collect scrap/Core, fight unchanged threats, enter sanctuary, repair five scrap for 35 chassis, Refit, extract/settle, and reload with unchanged values. |
| Save | Existing migration/repository suites pass; basalt save after damage/mutation round-trips exact schema keys and state; contact timer is absent. |
| Visual roster | Palette-only comparisons prove identical worm/hazard constants, state transitions, damage, quotas, rewards, ownership, and sanctuary behavior. |
| Export/public | Exact PCK URL, byte count, SHA-256, HTTP 200, `gameReady`, title-to-field, one visible damage tick, keyboard/touch exit, Smash, and no browser errors. |

### 6.9 Performance budget

Integer lattice sampling and majority checks run only during cell generation and use fixed O(1) work. Relative Web p95 may not regress by more than 10% against the same baseline route. Warm desktop p95 targets ≤16.7 ms; constrained portrait p95 targets ≤33.3 ms, while no sustained reference-device portrait frame time may exceed its previously established budget. Bright rim/crack accents are bounded to three simple strokes per visible lava cell and allocate no particle or material per cell. Existing enemy/hazard counts remain bounded.

### 6.10 Tuning defaults

| Setting | Default |
|---|---:|
| Macro-region | `32×32` cells |
| Forced teaching macro | `(1,0)` |
| Additional candidate frequency | `1 in 5` |
| Safe macro border | `2` cells |
| Value-noise lattice | `8` cells |
| Target lava share | `20–30%` after safety masks |
| Teaching outpost | `(40,10)` |
| Teaching pool center | Approximately `(45,10)` |
| Contact damage | `8 chassis` |
| Repeat cadence | `1.0 s` with immediate entry tick |
| Outpost/relay terrain margin | Existing `2.5` radius + `0.5` tile-footprint margin |
| Basalt luminance | Approximately `12–25%` |
| Ash luminance | Approximately `45–65%` |
| Lava core/crust | Approximately `75–100% / <20%` |

### 6.11 Rollback and done condition

LF-01 rollback removes LavaContact/profile/surface registration and restores the previous PCK; LF-02 rollback may independently remove safe-reservation/palette/art changes only if LF-01's teaching loop still satisfies safety. If objective reservations, old-save compatibility, or contact cadence fail, revert the whole affected increment. Never mask unsafe terrain with sanctuary immunity and never bump schema to rescue a procedural bug.

**Lava Fields is done** when the public build supports deterministic recurring Lava Fields, a readable safe teaching loop, exactly configured contact damage while touching lava and none after exit, unchanged movement/Smash/charge, safe outposts and relays, correct volcanic rock reveal, unchanged roster/economy/expedition/settlement, schema-3 and legacy reload, deterministic positive/negative restream, bounded streaming/rendering, accepted 512×512 assets/fallbacks, focused/full tests, exact immutable public PCK, matching pushed source, and clean worktrees.

## 7. Frozen Tundra

### 7.1 Player promise and smallest playable increment

> **Player promise:** Blue ice preserves Walker's current momentum and reduces steering until Walker reaches snow; it adds no input, damage type, meter, resource, or objective.

FT-01 adds the forced northern macro-region `(0,-1)`, broad normal-traction snow, contiguous short blue-ice lakes, snow exit aprons, safe outpost/objective areas, pure surface traction, and procedural renderer fallbacks. One route begins on snow, crosses a short lake with snow at both ends, and supports an existing encounter. Frozen ships last because it is the only biome that changes movement response.

FT-02 adds accepted `tundra_snow.png` and `blue_ice.png` assets, catalog/provenance checks, and the final cross-biome public matrix. The procedural fallback remains permanently available so art is never gameplay authority.

### 7.2 Architecture, files, data, and assets

| File | Concrete change |
|---|---|
| `scripts/frozen_tundra_profile.gd`, `data/biomes/frozen_tundra.tres` | Add validated generation and traction values only: macro/lattice sizes, salts, enabled probability, radii, aprons, normal parity, longitudinal/lateral acceleration, and drag. |
| `scripts/biome_resolver.gd` | Register forced `(0,-1)` and 1-in-4 hashed candidacy with the shared exclusive rank. |
| `scripts/infinite_world.gd` | Generate snow/blue ice only from eligible ground; expose `is_blue_ice`; apply boundary/obstacle/outpost aprons; reject icy relay candidates through direct unloaded-cell hashes; reveal local ground after rock destruction. |
| `scripts/surface_drive.gd` | Add a pure deterministic velocity adapter. Normal/snow/mud-safe/lava-safe/ruin paths reproduce current acceleration/deceleration; blue ice limits longitudinal and lateral change and applies low no-input drag. |
| `scripts/isometric_map.gd` | Configure the profile/adapter, pass existing input and occupied surface, preserve collision and facing authorities, register textures, and retain the existing mud hard cap. |
| `scripts/terrain_renderer.gd` | Add `snow` and `blue_ice` colors/textures plus clipped snow stipple and long ice grain/crack fallbacks. |
| `assets/textures/terrain/tundra_snow.png`, `blue_ice.png` | Add seamless 512×512 RGB derivatives: compact wind-packed snow and saturated cyan/blue ice with long grain, dark anchors, and subsurface cracks. |
| `scripts/visual_catalog.gd`, shared `SOURCES.md` | Require accepted textures and append provenance/hashes while retaining fallback playability. |
| `test/test_frozen_tundra.gd`, `test/test_contracts.gd`, `test/smoke.gd` | Add generation/topology, normal parity, ice behavior, frame-rate, keyboard/touch, safety, save, streaming, asset, and scene-level checks. |
| `README.md` | After implementation, state the one Frozen rule and unchanged controls/release path; do not add lore or a new system description.[2] |
| `export_presets.cfg` | Add the new scripts/profile to explicit resources as necessary while keeping Web/no-thread/terrain wildcard settings. |

### 7.3 Deterministic world generation

Floor-divide cells into 64×64 Frozen macro-regions. Force `(0,-1)` and select other candidates when `posmod(hash(region, FROZEN_REGION_SALT), 4) == 0`, subject to exclusive resolution. Preserve base rock/ruin/outpost semantics and map eligible sand/salt to snow or blue ice.

Blue-ice lakes use a 16-cell lattice. For the cell's lattice bucket and eight neighbors, derive an enabled flag with 55% probability, center jitter, and radius 4–8 from integer hashes. A cell is ice when it falls inside any enabled lake after safety masks. This fixed nine-bucket probe is O(1), allocation-free, and independent of generation order.

Force one-cell snow aprons at Frozen biome edges and around original rock/ruin cells. Force a four-cell snow service area around every deterministic outpost, exceeding the 2.5-cell sanctuary. Far relay candidate validation directly samples the radius-3 hold/approach area and rejects any candidate containing ice; it must not load candidate chunks or grow caches. These routes make stopping possible without changing relay or outpost behavior.

### 7.4 Rule integration and traction

`SurfaceDrive` receives current screen-space velocity, the existing desired input vector/run intent, clamped delta, current surface ID, and the already computed surface maximum. On ordinary surfaces, including snow, it reproduces 310 px/s² acceleration and 390 px/s² deceleration exactly. On blue ice it decomposes desired change into velocity-longitudinal and lateral components, clamps them independently, and uses low drag with no input. Maximum walk/run speed remains 150/225; ice never boosts above it.

Blue-ice defaults are 155 px/s² longitudinal acceleration, 68 px/s² lateral steering, and 24 px/s² no-input drag. Facing still follows requested quantized intent even while velocity turns slowly. Collision, blocked transitions, shutdown, placement, and the existing Smash brace may still zero velocity because they are pre-existing authorities. The current 0.05-second step cap and 0.05 speed snap remain.

When FT-01 moves normal velocity math into `SurfaceDrive`, parity tests must prove ordinary desert, ruin, snow, wetland, basalt, ash, and lava-safe movement equal the pre-FT baseline. Dark mud retains its 0.62 maximum and hard clamp; lava contact remains independent. No texture, color, particle, or renderer result may affect traction.

### 7.5 Enemy visual treatment without logic changes

Frozen acceptance keeps current enemy and weather simulation and may keep current visuals. A future visual-only treatment may select snow-dusted worm wake colors, white funnel colors, and whiteout storm colors, but it is explicitly outside FT-01/FT-02 unless approved as a zero-logic replacement. Tests must show identical FSM, damage, footprints, timing, rewards, caps, Alert ownership, and sanctuary behavior. No frost enemy family, freeze status, cold damage, or ice interaction is permitted.

### 7.6 Save/load and streaming

No velocity or traction state is persisted. Saving on blue ice restores player cell/facing and reconstructs the same ice, but velocity begins at `Vector2.ZERO`, matching current transient movement semantics. The next existing input accelerates from rest under ice traction. This behavior is documented and tested rather than expanding schema 3.

Destroyed generated rocks reveal coordinate-derived snow/ice ground; placed rocks remain blocked. Existing mutation arrays preserve meaning and bounds. Ten-region and larger positive/negative travel must retain exactly 25 loaded chunks, at most 1,600 active cells, at most 841 visible cells, no candidate-probe chunk loads, no biome Nodes/particles, and no dictionary growth after eviction.

### 7.7 Accessibility and mobile

Snow and ice differ by pattern and value as well as hue. Snow uses broad low-contrast packed drifts and sparse blue-gray grit; ice uses dark anchors, long directional grain, and cracks without white glare that obscures Walker, relays, sanctuary rings, worms, or telegraphs. Validate grayscale/high-readability at zoom 0.65 in 390×844, 844×390, and 1280×720.

Keyboard tests cover all eight directions, 90-degree turns, reversal, no-input coast, and snow braking. Touch tests cover low-strength and outer-ring vectors, run hysteresis, release while on ice, reduced-steering reacquisition, simultaneous SMASH, exclusions, handedness, and resize cancellation. There is no second joystick, brake button, ice meter, haptic pattern, or orientation lock.

### 7.8 Focused test matrix

| Area | Required focused coverage |
|---|---|
| Generation | Positive/negative, macro-edge, starter-edge, forced `(0,-1)`, outpost, rock, ruin, lake, and desert golden cells; shuffled load, eviction/revisit, and restart agree; distant searches find both Frozen and non-Frozen regions. |
| Topology/safety | Sampled lake components are contiguous; exits enter snow; one-cell biome/obstacle aprons and four-cell outpost areas contain no ice; radius-3 relay probes contain no ice and load no chunks. |
| Normal parity | Sand, salt, ruin, snow, wetland firm, basalt, ash, and lava retain 310/390 acceleration/deceleration, 150/225 maxima, delta cap, eight facings, corner checks, and screen/grid signs. Mud retains its independent cap. |
| Ice behavior | Enter at speed, release for one second, retain substantial nonzero momentum; apply 90-degree/reverse intent and turn materially less than snow; reach snow and resume normal braking immediately. Test 20/30/60/120 Hz and oversized supplied delta. |
| Keyboard/touch | Eight keyboard octants and analog vectors steer toward requested facing; Shift/outer-ring uses the same cap; release coasts; SMASH and Impact Charge remain current; collision cannot tunnel or bypass corners. |
| Systems | Link a relay from snow, use sanctuary/repair/Refit, collect/bank rewards, Smash rock/worm, and overlap current worm/weather while sliding; all damage/reward/timing/contest values remain unchanged. |
| Save | Legacy/current repository suites pass; snow/ice round trips preserve exact keys and state; ice regenerates; velocity resets to zero; malformed/future/backup behavior is unchanged. |
| Assets/export | Both textures are nonempty 512×512, repeat seamlessly, remain distinct in grayscale/portrait, close in Web export, and can be removed without disabling deterministic fallback simulation. |
| Public | Cache-busted desktop and `?mobile=1` portrait sessions reach ice, visibly coast/turn weakly, reach snow and brake, Smash once, use a safe objective, reload, and show no browser errors. |

### 7.9 Performance budget

Each Frozen cell inspects exactly nine lattice buckets with integer math and no allocations. Normal movement through `SurfaceDrive` may not introduce repeated world classification beyond the occupied surface query. Warm desktop Web p95 targets ≤16.7 ms and constrained-mobile p95 ≤33.3 ms; the fixed 600-frame comparison may not regress more than 10% from the same pre-FT route. Chunk, active-cell, visible-cell, save-size, enemy, hazard, and node-count bounds remain unchanged.

### 7.10 Tuning defaults

| Setting | Default |
|---|---:|
| Macro-region | `64×64` cells |
| Forced showcase | `(0,-1)` |
| Additional candidate frequency | `1 in 4` |
| Lake lattice | `16` cells |
| Enabled centers | `55%` |
| Lake radius | `4–8` cells |
| Target ice share | `20–30%` of Frozen ground |
| Boundary/obstacle apron | `1` snow cell |
| Outpost service area | `4` snow cells |
| Relay rejection area | Radius `3` |
| Normal/snow acceleration | `310 px/s²` |
| Normal/snow deceleration | `390 px/s²` |
| Ice longitudinal acceleration | `155 px/s²` |
| Ice lateral steering | `68 px/s²` |
| Ice no-input drag | `24 px/s²` |
| Walk/run maximum | `150 / 225 px/s` |
| Step cap / speed snap | `0.05 s / 0.05` |

### 7.11 Rollback and done condition

FT-01 rollback removes the Frozen profile/classification and `SurfaceDrive`, restoring the prior movement implementation and public PCK. Because FT changes a hot path, any normal-surface parity, corner collision, touch, or frame-rate failure triggers full FT-01 rollback rather than a tuning workaround. FT-02 art can roll back independently to procedural fallbacks. Saves need no transform because velocity and ice are never stored.

**Frozen Tundra is done** when the same pushed/public build streams exclusive snow/blue-ice regions indefinitely, blue ice retains momentum and reduces steering while snow restores exact baseline traction, and no new control or HUD mechanic appears. All eight keyboard directions, analog touch/run, mud cap, lava contact, Smash, charge, collision, objectives, outposts, sanctuary, roster, economy, mutations, legacy/schema-3 saves, responsive layouts, bounds, assets/fallbacks, performance, focused/full verification, immutable PCK matching, public desktop/portrait smoke, and clean worktrees must pass.

## 8. Cross-biome acceptance gate

The final three-biome build passes only when every row below is true in one clean candidate. A biome that works alone but breaks another biome is unfinished.

| Gate | Acceptance |
|---|---|
| Exclusive ownership | Every valid cell resolves to desert or exactly one biome. Forced Oasis `(0,0)`, Lava 32-cell `(1,0)`, and Frozen `(0,-1)` showcases are reachable and stable. Hashed overlaps resolve by coordinate rank, never generation order. |
| One-rule isolation | Mud only changes Walker maximum speed; lava only emits chassis damage while touched; ice only changes traction. No cell combines rules and no rule changes enemies, rewards, objectives, or economy. |
| Baseline movement | Desert, firm wetland, basalt, ash, snow, and ruin reproduce current eight-direction mappings, 2:1 displacement, 150/225 maxima, 310/390 traction, normalized diagonals, corner checks, camera lead, animation, and Impact Charge. |
| Combined surface behavior | Mud's maximum clamp remains effective after `SurfaceDrive`; lava does not alter velocity; ice does not change damage; moving directly across biome boundaries switches only the occupied-cell rule. |
| Starter and objectives | The 18×18 starter is behaviorally unchanged. All outpost sanctuaries are visibly safe. Relay hold/approach areas are stoppable and nondamaging without changing link radius, duration, registry, or saved objective identity. |
| Existing roster and economy | Worms, tornadoes, sandstorms, Alert ownership, rewards, scrap/Core rates, repair, Refit, extraction, settlement, and modifiers match current neutral contracts. Visual palette selection is removable without a simulation diff. |
| Save compatibility | Schema-1/2 fixtures and exact-key schema 3 pass. Format remains 3, generation version remains 1, snapshots retain four mutation arrays, and no biome/surface/contact/traction/velocity key exists. Saves at mud, lava-safe ground after damage, snow, and ice reconstruct deterministically. |
| Determinism | Positive, negative, macro-edge, overlap, starter, objective, and coordinate-limit golden cells agree across generation order, chunk eviction, process restart, and Web/native runs. No global RNG or mutable procedural state participates. |
| Streaming and memory | Exactly 25 loaded chunks, ≤1,600 active cells, and ≤841 visible cells; no per-cell Nodes/materials/bodies, no unloaded-surface retention, no objective-probe chunk loads, and no growth over long travel. |
| Accessibility and touch | Safe/special pairs remain distinguishable by value and texture in grayscale at zoom 0.65. Desktop, 844×390 touch landscape, and 390×844 portrait preserve HUD, one joystick, one SMASH button, exclusions, handedness, run hysteresis, and unobstructed safe exits. |
| Performance | Each increment meets its chunk-generation budget and the same fixed-route 600-frame p95 is no worse than 10% against its immediate green predecessor. Final warm targets are desktop Web p95 ≤16.7 ms and constrained-mobile p95 ≤33.3 ms. |
| Release integrity | One clean `./verify.sh --release` passes; HTML/JS/WASM/PCK are nonempty; no test/addon/provenance/artifact resource enters the PCK; public JS requests the exact immutable PCK; URL, bytes, and SHA-256 match; desktop/portrait browser play has no errors. |
| Source integrity | The deployed source commit equals pushed `origin/main`, the WebDev pointer references that commit's PCK, and both worktrees are clean. No stale PCK or unrelated hot-file edit is included. |

A representative final gameplay smoke must start a new expedition, enter all three guaranteed showcase regions, demonstrate each rule once, Smash a rock and an exposed worm, survive current tornado/sandstorm contact, link all three relays, use a safe outpost for repair/Refit, collect existing rewards, extract/settle, save, reload, and revisit evicted positive and negative chunks. Values and timings must remain those already owned by current data and tests; the smoke does not become a second source of balance constants.

## 9. Explicit exclusions

The following work is outside this plan. Adding any item requires a separately approved increment and cannot be used to satisfy a biome's one rule.

| Excluded area | Not included |
|---|---|
| Controls and UI | New movement, brake, jump, dodge, interact, resistance, cool, or biome buttons; second joystick; radial menu; mud/heat/ice meter; status stack; immunity icon; new input action; orientation lock. |
| Terrain simulation | Mud accumulation, water depth, swimming, lava propagation, cooling, ice cracking/breaking, footprints with state, moving platforms, fluid physics, reactive terrain state machines, cross-chunk simulation, or serialized generated cells. |
| Combat and roster | New enemy family, biome enemy AI, changed worm/hazard damage or timing, altered hitboxes/telegraphs/rewards/quotas, elemental damage trees, freeze/burn/stamina systems, or biome-specific loot multipliers. |
| Progression and economy | New currency, crafting tree, survival resource, resistance module, biome gear, unlock tree, objective type, relay reward, outpost service, settlement rule, or lore-gated progression. |
| World content | A fourth biome, finite biome maps/scenes, palms/reed prop Nodes, vents with behavior, authored settlements, quest lines, lore symbols, currencies, or mandatory surface crossings. Decorative marks inside terrain textures are acceptable only when inert. |
| Presentation | New HUD art, Walker atlas, enemy atlas, audio suite, per-cell particles, normal maps, shaders that become gameplay authority, or concept-art export. Optional enemy palettes remain visual-only and may be cut. |
| Architecture and persistence | Autoload biome manager, second terrain renderer, per-biome scene tree, biome save fields, schema bump, generation-version negotiation, cache that grows with travel, edits to save migration/repository behavior, or duplicate input/collision authority. |
| Process | Evidence ledgers, review folders, audit records, duplicate verification pipelines, speculative framework releases, or documentation bundles beyond the source plan, concise release note, and shared terrain provenance required for the assets. |

## 10. Implementation boundaries and failure policy

The source allowlist in each biome section is intentional. `save_repository.gd`, `save_migrator.gd`, `world_state_store.gd`, `run_state.gd`, `profile_state.gd`, economy resources, project input actions, `mobile_controls.gd`, `isometric_controls.gd`, `responsive_camera.gd`, and `responsive_viewport.gd` are regression boundaries rather than biome extension points. Lava's optional visual palette is the only planned reason to touch worm/hazard/atmosphere scripts, and those diffs must be separable color/asset selection.

When a failure implicates generation compatibility, movement parity, objective safety, schema exactness, streaming bounds, or public artifact identity, the increment is blocked and rolls back. Tuning may adjust values only inside the documented legal ranges and must update golden/property tests with the same commit. Tuning cannot compensate by changing enemy speed, hazard damage, acceleration outside the Frozen surface adapter, camera zoom, economy, relay timing, sanctuary radius, or mobile thresholds.

## References

[1]: ../concept/simple-biomes/SIMPLE_BIOME_CONCEPT.md "Walker's Wake Simple Biome Concept"
[2]: ../../README.md "Walker's Wake README and shipped controls"
[3]: WALKERS_WAKE_IMPLEMENTATION_PLAN.md "Walker's Wake implementation contracts and shipped architecture"
[4]: ../../scripts/infinite_world.gd "InfiniteWorld streaming, terrain, hashing, and mutation authority"
[5]: ../../scripts/isometric_map.gd "Field composition, movement, projection, damage, and save integration"
[6]: ../../scripts/isometric_controls.gd "Keyboard direction, run, and Smash input mappings"
[7]: ../../scripts/mobile_controls.gd "Floating joystick, run hysteresis, exclusions, handedness, and SMASH"
[8]: ../../scripts/terrain_renderer.gd "Projected terrain polygon, UV, tint, elevation, and texture drawing"
[9]: ../../scripts/save_repository.gd "Schema-3 validation, primary/backup recovery, quarantine, and atomic commit"
[10]: ../../scripts/save_migrator.gd "Legacy schema migration boundary"
[11]: ../../scripts/balance_profile.gd "Validated balance Resource convention"
[12]: ../../data/balance/default_balance.tres "Default shipped balance values"
[13]: ../../scripts/visual_catalog.gd "Required runtime visual asset validation"
[14]: ../../scripts/responsive_viewport.gd "Responsive design dimensions and 0.65–1.2 camera zoom"
[15]: ../../scripts/responsive_camera.gd "Size-driven responsive camera application"
[16]: ../../scripts/sandworms.gd "Existing sandworm simulation authority"
[17]: ../../scripts/desert_hazards.gd "Existing tornado and sandstorm simulation authority"
[18]: ../../scripts/encounter_director.gd "Existing Alert encounter ownership"
[19]: ../../export_presets.cfg "Web export resource list, terrain wildcard, and no-thread settings"
[20]: ../../verify.sh "Import, lint, smoke, boot, and clean Web release gate"
[21]: ../../test/test_contracts.gd "Focused contract-suite aggregator"
[22]: ../../test/test_save_repository.gd "Schema-3 repository regression suite"
[23]: ../../scripts/performance_sampler.gd "Bounded 600-frame performance sampler"
[24]: ../../test/test_visual_catalog.gd "Runtime asset and Walker frame/contact contracts"
