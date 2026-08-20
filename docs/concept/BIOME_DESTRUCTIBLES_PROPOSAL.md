# Walker’s Wake — Biome-Specific Destructibles Proposal

**Goal:** Replace the generic desert-rock presentation in every non-desert biome with biome-native destructibles while preserving the proven Smash, collision, salvage, save, and streaming contracts.

**Affected area:** Static destructible rendering, generated runtime sprites, visual catalog validation, biome-focused tests, and impact feedback copy.

**Done condition:** Every generated rock cell still behaves identically, but its visual identity is selected deterministically from the current biome; destroyed cells and placed obstacles remain save-compatible; all sprites are GPT Image 2 assets with transparent runtime derivatives; the clean Web export and public build pass.

## Recommendation

Treat the change as a **presentation adapter over existing rock truth**, not a new resource or persistence system. Internally, a destructible cell remains a rock because `InfiniteWorld` already owns deterministic placement, blocking, breaking, scrap reward, world mutation, and schema-compatible `destroyed_rocks` / `placed_rocks` storage. `WorldObjects` should ask the world for the cell’s biome, choose a deterministic visual variant, and draw the corresponding sprite.

This gives each biome an immediate silhouette language without risking save migration or duplicating gameplay code. The desert keeps its iron-rock cluster. Wetlands, tundra, and lava fields receive two visually distinct variants each.

## Runtime set

| Biome | Primary destructible | Secondary variant | Readability role |
|---|---|---|---|
| **Desert** | Existing iron-rock cluster | Procedural fallback | Low, wide obstacle that preserves the current baseline |
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
            return &"desert_rock"
```

The selector belongs in a pure `BiomeDestructibles` adapter so tests can validate it without constructing a render tree. `WorldObjects` binds the existing `InfiniteWorld` reference and consumes this read-only classification during `_draw()`.

## Art contract

Every runtime sprite must use the game’s exact 2:1 isometric presentation and the established painterly-industrial texture language. Each asset is a single complete object on a transparent background, with a centered bottom contact point, clean alpha, no ground tile, no cast shadow beyond a small contact shadow, no text, no characters, and no additional props.

The accepted runtime derivative is a 256×256 RGBA PNG. The object should occupy most of the canvas but preserve transparent breathing room for vertical silhouettes. Runtime drawing scales variants to readable sizes while keeping collision on the underlying cell.

| Asset | Approximate on-screen bounds | Pivot intent |
|---|---:|---|
| Mangrove snag | 88×118 px | Trunk contact centered at the bottom |
| Rotting stump | 76×66 px | Root base centered at the bottom |
| Snow-capped rock | 78×60 px | Stone base centered at the bottom |
| Wind-bent pine | 92×138 px | Trunk contact centered at the bottom |
| Basalt chimney | 82×104 px | Vent base centered at the bottom |
| Obsidian cluster | 82×64 px | Cluster base centered at the bottom |

A procedural rock fallback remains available for missing optional textures, but the six new paths become required release assets through `VisualCatalog`.

## Feedback

The existing Smash effect can remain geometrically unchanged, but the status line should use the semantic object name: **WOOD SALVAGED**, **FROZEN OBSTACLE SALVAGED**, or **VOLCANIC OBSTACLE SALVAGED** rather than always reporting a rock. This is presentation copy only; scrap arithmetic remains authoritative in `InfiniteWorld`.

Impact debris can remain the current generic particles for the first increment. Biome-colored debris is a reversible polish follow-up, not a blocker. The desert has survived without a forestry department; it can wait one release.

## Lean implementation

| Change | Goal | Affected area | Done condition |
|---|---|---|---|
| **1. Asset set** | Produce six coherent transparent GPT Image 2 sprites and concise source notes. | `assets/destructibles/`, source note, import metadata. | All six 256×256 RGBA textures load with clean alpha and consistent 2:1 isometric lighting. |
| **2. Deterministic adapter** | Map biome and cell to a visual kind without changing saved rock truth. | New `biome_destructibles.gd`, `world_objects.gd`, `isometric_map.gd`. | The same cell always resolves to the same variant; unknown/missing assets fall back to desert rock. |
| **3. Runtime rendering** | Draw biome-native sprites at stable bottom-centered pivots. | `world_objects.gd`, visual catalog. | Non-desert rock cells show native assets, remain one-cell blockers, break normally, and drop exactly two scrap. |
| **4. Focused coverage** | Protect selection, save compatibility, and rendering assets. | Biome tests, visual catalog tests, smoke checks. | Tests prove both variants occur per biome, rock mutation schema is unchanged, and all textures meet runtime dimensions. |
| **5. Release** | Publish the exact verified bundle. | Clean export, attached WebDev deployment, live browser smoke, Git. | The exported and public builds boot and show unique wetland, frozen, and lava destructibles without regressions. |

## Acceptance criteria

A player crossing a biome boundary should recognize the new biome from obstacles before reading the HUD. No tree or chimney may imply a wider collision footprint than one cell. Tall sprites must remain behind Walker when appropriate under the existing diagonal draw order. Breaking any variant must preserve the same save key, clear the blocker once, yield two scrap once, and remain destroyed after reload. Placed rocks from older saves should adopt the current biome’s visual automatically without migration.
