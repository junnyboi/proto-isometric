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

Press **Enter** or select **BEGIN** to enter the desert. Use **WASD** or the **arrow keys** for weighted eight-direction movement, hold **Shift** to run at 1.5× speed, use **Space**, **J**, or **K** for an impact strike, and press **Escape** to return to the title. Break rocks with the strike, then move over the dropped teal scrap to collect it.

Rock destruction resolves on Cardinal's attack contact frame with bounded camera shake, rock fragments, and dust. Broken rocks, uncollected scrap, collected scrap inventory, Cardinal's cell, and facing are saved atomically to `user://walkers-wake-world.json` and restored when the desert scene or Web session returns. Invalid saves are ignored without partially mutating the world.

The camera follows Cardinal with eased motion and velocity look-ahead. Approved square-cell directional sheets dropped into `assets/cardinal/` are auto-bound through the contract in [`assets/cardinal/SOURCES.md`](assets/cardinal/SOURCES.md); missing sheets use the animated procedural proxy.

## Concept

Read [`docs/concept/WALKERS_WAKE_PROPOSAL.md`](docs/concept/WALKERS_WAKE_PROPOSAL.md) for the proposed direct-control exploration, caravan, and archaeological-discovery design.

## Links

- Live game: https://proto-web-bylaknug.manus.space
- Source: https://github.com/junnyboi/proto-isometric
