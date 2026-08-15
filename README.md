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

Press **Enter** or select **BEGIN** to enter the desert. Use **WASD** or the **arrow keys** for weighted eight-direction movement, hold **Shift** to run at 1.5× speed, use **Space**, **J**, or **K** for an impact strike, and press **Escape** to return to the title. On detected mobile devices, press and hold anywhere outside the attack control to summon a floating analog joystick, drag for proportional eight-direction drive, and release to coast naturally; the circular **SMASH** button at bottom right routes into the same contact-frame strike. Break rocks with the strike, then move over the dropped teal scrap to collect it. Harvested outposts repair 35 chassis for five scrap; crafting and upgrades are visible but locked.

Rock destruction resolves on Cardinal's attack contact frame with bounded camera shake, rock fragments, and dust. Terrain mutations are stored as compact deltas over the deterministic world seed; broken or placed rocks, dropped and collected scrap, chassis integrity, Cardinal's cell, and facing are saved atomically to `user://walkers-wake-world.json`. Existing schema-one saves migrate on load, while invalid saves are ignored without partially mutating the world.

Dust devils telegraph for three seconds, activate as fast single-tile hazards for 20 seconds, and deal six chassis damage per second. Six-tile sandstorms cross the active world window from one edge to the other with their three-tile side leading for maximum coverage and deal three chassis damage per second. Both are indestructible and nonblocking, so survival depends on movement rather than punching the weather. Multiple instances of both hazards can coexist.

Sandworms are the first defeatable hunters. They emerge from the streamed desert, pursue Cardinal inside an eight-tile detection range, and bite for ten chassis damage per attack. Each worm exposes a world-space health bar and falls after four Cardinal melee impacts. Linking to a harvested outpost forces nearby worms to disperse, making service pads reliable combat sanctuaries.

Hazard contact deals one immediate tick, then repeats once per uninterrupted second while Cardinal remains inside the continuous footprint. Leaving clears that contact timer; re-entry immediately damages again. The heat ripple uses world-space phase and is masked to sand tile tops only, so camera movement does not drag it across the desert and salt, rock, ruin, outpost, scrap, and character pixels remain undistorted. Destroyed rock tiles join the sand mask immediately after salvage.

Chassis hits flash Cardinal and the screen, throw bounded sparks and camera kick, identify the damage source in the HUD, and play a short generated armor-impact cue. At zero chassis Cardinal enters a persistent shutdown state: drive, impact, collection, and field repair remain offline until the player returns to the title. The shutdown overlay and low-pitched final cue make the failure state unambiguous.

The camera follows Cardinal with eased motion, velocity look-ahead, and a 1.2× zoom for a 20% closer field view. Approved square-cell directional sheets dropped into `assets/cardinal/` are auto-bound through the contract in [`assets/cardinal/SOURCES.md`](assets/cardinal/SOURCES.md); missing sheets use the animated procedural proxy.

Terrain is a deterministic, practically unbounded procedural stream. The runtime lazily keeps a 5×5 ring of eight-tile chunks around Cardinal, evicts distant chunk data, and submits only a 29×29 cell window to terrain, object, and haze drawing. Four accepted 512×512 material textures in `assets/textures/terrain/` use continuous low-frequency UV warping and shared-vertex tint variation to break repetition without creating tile seams. Wind-blown sand particles and a Web-compatible heat-haze shader supply the ambient desert layer.

## Concept

Read [`docs/concept/WALKERS_WAKE_PROPOSAL.md`](docs/concept/WALKERS_WAKE_PROPOSAL.md) for the proposed direct-control exploration, caravan, and archaeological-discovery design.

## Links

- Live game: https://proto-web-bylaknug.manus.space
- Source: https://github.com/junnyboi/proto-isometric
