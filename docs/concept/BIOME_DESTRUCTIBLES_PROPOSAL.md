# Walker’s Wake — Biome-Specific Destructibles Proposal

**Goal:** Give every biome, including the desert, two generated biome-native destructibles while preserving the proven Smash, collision, salvage, save, and streaming contracts.

**Affected area:** Static destructible rendering, generated runtime sprites, visual catalog validation, biome-focused tests, and impact feedback copy.

**Done condition:** Every generated rock cell still behaves identically, but its visual identity is selected deterministically from the current biome; destroyed cells and placed obstacles remain save-compatible; all sprites are GPT Image 2 assets with transparent runtime derivatives; the clean Web export and public build pass.

## Recommendation

Treat the change as a **presentation adapter over existing rock truth**, not a new resource or persistence system. Internally, a destructible cell remains a rock because `InfiniteWorld` already owns deterministic placement, blocking, breaking, scrap reward, world mutation, and schema-compatible `destroyed_rocks` / `placed_rocks` storage. `WorldObjects` should ask the world for the cell’s biome, choose a deterministic visual variant, and draw the corresponding sprite.

This gives each biome an immediate silhouette language without risking save migration or duplicating gameplay code. Desert, wetlands, tundra, and lava fields each receive two visually distinct generated variants.

## Runtime set

| Biome | Primary destructible | Secondary variant | Readability role |
|---|---|---|---|
| **Desert** | Sunscoured sandstone cluster | Ironstone knuckle | Bright stepped slabs and dense dark mineral blocks establish two readable desert silhouettes |
| **Oasis Wetlands** | Mangrove snag | Rotting stump | Vertical vegetation and broad decayed wood distinguish wetland routes from desert rubble |
| **Frozen Tundra** | Snow-capped granite boulder | Wind-bent pine | White stone reads against blue ice; dark evergreen silhouette reads against snow |
| **Lava Fields** | Basalt chimney | Obsidian clinker cluster | Tall cooled vent and low glassy fragments remain legible against ash, basalt, and lava |

All variants remain one-cell blockers, break from the current Smash or Ram Plating path, and drop the existing two scrap. The visual must never alter attack geometry, required charge, navigation, reward, or save state.

## Deterministic selection

`WorldObjects` should use the cell’s authoritative biome and a stable coordinate hash. No variant ID needs to be persisted because the biome and cell are already deterministic.

```gdscript
func _destructible_kind(cell: Vector2i) -> StringName:
    var variant: int = posmod(cell.x * 37 + cell.y * 61 + cell.x * cell.y * 11, 2)
    match _world.call("_biome_at", cell):
        &"oasis":
            return &"wetland_mangrove" if variant == 0 else &"wetland_stump"
        &"frozen":
            return &"frozen_snow_rock" if variant == 0 else &"frozen_pine"
        &"lava":
            return &"lava_basalt_chimney" if variant == 0 else &"lava_obsidian_cluster"
		_:
			return &"desert_sandstone_cluster" if variant == 0 else &"desert_ironstone_outcrop"
```

The selector belongs in a pure `BiomeDestructibles` adapter so tests can validate it without constructing a render tree. `WorldObjects` binds the existing `InfiniteWorld` reference and consumes this read-only classification during `_draw()`.

## Art contract

Every runtime sprite must use the game’s exact 2:1 isometric presentation and the established painterly-industrial texture language. Each asset is a single complete object on a transparent background, with a centered bottom contact point, clean alpha, no ground tile, no cast shadow beyond a small contact shadow, no text, no characters, and no additional props.

The accepted runtime derivative is a 256×256 RGBA PNG. The object should occupy most of the canvas but preserve transparent breathing room for vertical silhouettes. Runtime drawing scales variants to readable sizes while keeping collision on the underlying cell.

| Asset | Approximate on-screen bounds | Pivot intent |
|---|---:|---|
| Sunscoured sandstone | 84×66 px | Broad stone base centered at the bottom |
| Ironstone knuckle | 82×70 px | Dense stone base centered at the bottom |
| Mangrove snag | 88×118 px | Trunk contact centered at the bottom |
| Rotting stump | 76×66 px | Root base centered at the bottom |
| Snow-capped rock | 78×60 px | Stone base centered at the bottom |
| Wind-bent pine | 92×138 px | Trunk contact centered at the bottom |
| Basalt chimney | 82×104 px | Vent base centered at the bottom |
| Obsidian cluster | 82×64 px | Cluster base centered at the bottom |

All eight generated texture paths are required release assets. Missing or invalid textures fail validation rather than silently reverting to procedural obstacle graphics.

## Feedback

The existing Smash effect can remain geometrically unchanged, but the status line should use the semantic object name: **WOOD SALVAGED**, **FROZEN OBSTACLE SALVAGED**, or **VOLCANIC OBSTACLE SALVAGED** rather than always reporting a rock. This is presentation copy only; scrap arithmetic remains authoritative in `InfiniteWorld`.

The post-release debris increment now routes each broken object kind into a biome-owned palette. Wetland wood throws dark bark, pale splinters, and olive moss; frozen stone throws snow, granite, and blue ice; frozen pine adds deep evergreen; lava objects throw basalt, ash, and restrained orange cooling fragments. Desert objects retain the original warm rock family.

`ImpactEffects` retains its fixed pool of 128 lightweight particle dictionaries and adds a fixed pool of 64 nonblocking `RigidBody2D` obstacle fragments. Each material family supplies a distinct shape, palette, gravity, launch-speed, size, and spin profile. Active visual particles remain capped at 128, saturation reclaims an active slot instead of allocating, and every destructible fragment fades and returns to the pool at the one-second boundary. Smash and Ram Plating share this transient, unsaved path.

## Lean implementation

| Change | Goal | Affected area | Done condition |
|---|---|---|---|
| **1. Asset set** | Produce eight coherent transparent GPT Image 2 sprites and concise source notes. | `assets/destructibles/`, source note, import metadata. | All eight 256×256 RGBA textures load with clean alpha and consistent 2:1 isometric lighting. |
| **2. Deterministic adapter** | Map biome and cell to a visual kind without changing saved rock truth. | `biome_destructibles.gd`, `world_objects.gd`, `isometric_map.gd`. | The same cell always resolves to the same generated variant; every registered texture is required and validated. |
| **3. Runtime rendering** | Draw biome-native sprites at stable bottom-centered pivots. | `world_objects.gd`, visual catalog. | Every rock cell shows a native generated asset, remains a one-cell blocker, breaks immediately, and drops exactly two scrap. |
| **4. Focused coverage** | Protect selection, save compatibility, and rendering assets. | Biome tests, visual catalog tests, smoke checks. | Tests prove both variants occur per biome, rock mutation schema is unchanged, and all textures meet runtime dimensions. |
| **5. Release** | Publish the exact verified bundle. | Clean export, live smoke, visual certification, Git. | The validated build boots and shows unique desert, wetland, frozen, and lava destructibles without regressions. |

## Acceptance criteria

A player crossing a biome boundary should recognize the new biome from obstacles before reading the HUD. No tree or chimney may imply a wider collision footprint than one cell. Tall sprites must remain behind Walker when appropriate under the existing diagonal draw order. Breaking any variant must preserve the same save key, clear the blocker once, yield two scrap once, and remain destroyed after reload. Placed rocks from older saves should adopt the current biome’s visual automatically without migration.
