# Instant Obstacle Destruction and Biome Debris Proposal

**Author:** Manus AI
**Target branch:** `agent2/instant-obstacle-destruction`

## Outcome

An accepted Smash against an obstacle will mutate authoritative world state immediately when the attack begins. The obstacle sprite and blocking tile will disappear in the same gameplay step, the cell will become walkable, scrap and persistence will update, and a destruction feedback event will emit without waiting for the Walker contact-frame animation. Enemy damage will remain contact-frame-driven so this change does not make creature attacks resolve early.

The six existing generated non-desert obstacles remain unchanged. The desert procedural circles and crack lines will be replaced by two deterministic GPT Image 2 sprite variants selected from the obstacle cell coordinates, preserving the current save schema because obstacle kind remains presentation-only.

| Biome | Obstacle/debris identity | Fragment silhouette | Physics character | Palette |
|---|---|---|---|---|
| Desert | **Sunscoured Sandstone Cluster** and **Ironstone Knuckle** | Chipped wedges and irregular stone polygons | Strong upward scatter, medium-heavy gravity, brisk rotation | Ochre, rust, warm tan, dark iron brown |
| Oasis Wetlands | Mangrove and stump | Damp wood splinters and short bark chips | Wider lateral scatter, lighter gravity, lively tumbling | Dark bark, moss olive, wet umber |
| Frozen Tundra | Snow rock and frozen pine | Diamond ice chips or frost-pale splinters | Crisp high arc, lighter gravity, fast glinting rotation | Ice white, cyan, slate, cold wood green |
| Lava Fields | Basalt chimney and obsidian cluster | Jagged triangular volcanic shards | Forceful scatter, heavier gravity, rapid spin | Charcoal, obsidian black, ash gray, ember orange |

## Runtime contract

Debris fragments will be pooled `RigidBody2D` nodes. Every fragment uses `collision_layer = 0` and `collision_mask = 0`, contains no collision shape, and therefore cannot block, push, damage, or target the Walker. Linear velocity, angular velocity, and gravity are handled by Godot’s 2D physics server. The effects controller owns only deterministic activation, color/shape selection, alpha fade, the one-second lifetime, and pooling.

The pool remains hard bounded. A saturated emission reclaims the oldest active fragment rather than allocating indefinitely. Accessibility quality and VFX-intensity settings continue to scale fragment counts. All fragments begin fading immediately and are hidden, frozen, and returned to the pool at exactly one second.

## Desert rock visual specification

Both desert props use a centered three-quarter isometric view on a true transparent 1:1 canvas with a low, broad ground footprint. They must match the existing generated destructibles: compact readable silhouettes, clean alpha, restrained detail, no scenery, no ground tile, no cast shadow, no text, and no detached particles.

The **Sunscoured Sandstone Cluster** is a warm ochre formation of stacked, wind-rounded slabs with pale sunlit top planes, rust-colored seams, and a few chipped edges. The **Ironstone Knuckle** is a lower, denser mound of dark red-brown angular boulders with black mineral streaks, limited tan dust, and a visibly different silhouette from the sandstone cluster.

## Acceptance criteria

| Requirement | Verification |
|---|---|
| Obstacle and blocking state clear instantly | End-to-end Smash test checks `has_destructible_rock == false` and `is_walkable == true` immediately after `attack()` returns |
| No delayed duplicate destruction | Contact-frame processing cannot emit a second break event or debris burst |
| Debris is biome/material specific | Catalog tests verify distinct shape, palette, gravity, speed, and rotation profiles |
| Debris uses Godot 2D physics | Runtime tests verify active fragments are `RigidBody2D` nodes with linear/angular velocity and nonzero gravity scale |
| Debris never obstructs | Every active fragment has collision layer and mask zero and no collision shape |
| Debris fades and expires | Lifecycle tests verify visible fragments before 1.0 seconds and zero active fragments at 1.0 seconds |
| Desert procedural fallback is gone | Both desert variants load 256 × 256 transparent textures; `world_objects.gd` no longer contains procedural rock drawing |
| Runtime visual quality | Xvfb capture shows both desert variants plus all biome debris profiles without clipping, opaque backgrounds, or persistent fragments |
