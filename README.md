# Proto Isometric — WALKER'S WAKE

A Godot 4.7.1 desert exploration prototype built on an exact 2:1 isometric grid.

## Develop

```bash
$HOME/bin/godot --path .
```

Build a small playable change, then run the fast check:

```bash
./verify.sh
```

For a Web release:

```bash
./verify.sh --release
```

The release command writes the HTML, JavaScript, WASM, and PCK bundle to `/home/ubuntu/proto-isometric-build/web`.

## Controls

Press **Enter** or select **BEGIN** to enter the desert. Use **WASD** or the **arrow keys** for weighted eight-direction movement, hold **Shift** to run at 1.5× speed, use **Space**, **J**, or **K** for an impact strike, and press **Escape** to return to the title. Break rocks with the strike, then move over the dropped teal scrap to collect it. Harvested outposts repair 35 chassis for five scrap; crafting and upgrades are visible but locked.

Rock destruction resolves on Cardinal's attack contact frame with bounded camera shake, rock fragments, and dust. Broken rocks, uncollected scrap, collected scrap inventory, chassis integrity, Cardinal's cell, and facing are saved atomically to `user://walkers-wake-world.json` and restored when the desert scene or Web session returns. Invalid saves are ignored without partially mutating the world.

Dust devils telegraph for three seconds, activate as fast single-tile hazards for 20 seconds, and deal two chassis damage per second. Six-tile sandstorms cross the map from any edge with their three-tile side leading for maximum coverage and deal one chassis damage per second. Both are indestructible and nonblocking, so survival depends on movement rather than punching the weather. Multiple instances of both hazards can coexist.

Chassis hits flash Cardinal and the screen, throw bounded sparks and camera kick, identify the damage source in the HUD, and play a short generated armor-impact cue. At zero chassis Cardinal enters a persistent shutdown state: drive, impact, collection, and field repair remain offline until the player returns to the title. The shutdown overlay and low-pitched final cue make the failure state unambiguous.

The camera follows Cardinal with eased motion and velocity look-ahead. Approved square-cell directional sheets dropped into `assets/cardinal/` are auto-bound through the contract in [`assets/cardinal/SOURCES.md`](assets/cardinal/SOURCES.md); missing sheets use the animated procedural proxy.

Terrain shape, elevation, collision, and persistence remain procedural. Four accepted 512×512 material textures in `assets/textures/terrain/` use continuous low-frequency UV warping and shared-vertex tint variation to break repetition without creating tile seams. Wind-blown sand particles and a Web-compatible heat-haze screen shader supply the ambient desert layer.

## Concept

Read [`docs/concept/WALKERS_WAKE_PROPOSAL.md`](docs/concept/WALKERS_WAKE_PROPOSAL.md) for the proposed direct-control exploration, caravan, and archaeological-discovery design.

## Links

- Live game: https://proto-web-bylaknug.manus.space
- Source: https://github.com/junnyboi/proto-isometric
