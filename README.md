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

Press **Enter** or select **BEGIN** to enter the desert. Use **WASD** or the **arrow keys** for direct eight-direction movement, hold **Shift** to run at 1.5× speed, and press **Escape** to return to the title.

## Concept

Read [`docs/concept/WALKERS_WAKE_PROPOSAL.md`](docs/concept/WALKERS_WAKE_PROPOSAL.md) for the proposed direct-control exploration, caravan, and archaeological-discovery design.

## Links

- Live game: https://proto-web-bylaknug.manus.space
- Source: https://github.com/junnyboi/proto-isometric
