# Proto Isometric — WALKER'S WAKE

**Walker's Wake** is a Godot 4.7.2, 2:1 isometric desert expedition game. Drive Walker—a compact gorilla-like salvage robot—through an infinite streamed wasteland, build Impact Charge, counter hunting sandworms, link three relays, survive escalating Alerts, install one-run Refit modules, and return to an outpost to extract.

## Play

Live Web build: https://proto-web-bylaknug.manus.space

Press **Enter** or select **BEGIN** to deploy. Use **WASD** or the **arrow keys** for weighted eight-direction movement, hold **Shift** to run, and press **Space**, **J**, or **K** for Walker's contact-frame Smash. On mobile, hold outside UI exclusions to summon the floating joystick; pushing into its outer ring engages the same run path, while the single **SMASH** button supports simultaneous movement and attack. Each biome carries a two-track acoustic-forward score: an active theme and a quieter, near-percussionless peaceful alternate selected through a non-repeating randomized shuffle. Strings, winds, environmental sound, and tuned per-biome gains preserve combat-SFX clarity; louder ambience reinforces each environment, while track rotations and terrain changes use the same bounded equal-power crossfade. Desert's active theme adds sparse invented-language contralto calls, while Lava Fields' active theme adds an original low male choir. Left-handed mirroring, haptics, Master/SFX/Music/Ambience levels, UI scale, reduced flash, and camera shake are available through **ACCESS** on the title and field screens.

## Expedition loop

The run starts with a nearby relay and two deterministic streamed objectives beyond it. Linking relays raises Alert from I to III: a hunter, then a hunter with dust devils, then a hunter inside a broad storm front. Outposts suppress directed pressure and provide repair plus one atomic Refit purchase per expedition.

Sandworms use a readable Burrow → Intercept → Expose → Dive cycle. Walker can damage them only during Expose. Four valid hits defeat a worm and create one persistent run-scoped Core/scrap reward. Impact Charge retains its contact, two-cell line, and three-cell fan bands; the Worn Plates starter module increases charge gain without changing damage or footprint.

Refit offers **Ram Plating**, **Aftershock**, and **Storm Seal**. Ram Plating converts a charged running collision into one normal rock break, Aftershock extends the existing high-charge punish window, and Storm Seal reduces weather damage only while running. Each effect uses the existing movement or Smash controls—Walker has enough buttons already.

After all three relays, entering any outpost extracts automatically. Success banks the run exactly once and presents a deterministic two-of-three next-run modifier offer: **Hot Front**, **Brood Ground**, or **Dead Grid**. Failure loses all unbanked Cores and half the run scrap using deterministic rounding, then provides an immediate retry. Terminal summaries, pending choices, resumable expeditions, world mutations, and profile progression survive reload.

## Runtime architecture

The world keeps a bounded 5×5 ring of eight-cell chunks and renders a 29×29 cell window. Terrain, objective placement, encounter composition, reward rolls, and replay modifiers are deterministic. Schema-3 persistence uses typed `RunState` and `ProfileState`, primary/backup recovery, atomic replacement, strict bounds, schema-1/2 migration, and quarantine for malformed or future data. Accessibility preferences persist separately from the world save.

The HUD consumes a sealed semantic snapshot and includes a compact expedition radar, non-modal first-run onboarding, objective/Alert truth, Core and scrap wallets, active modifier context, and responsive desktop/mobile safe areas. Generated runtime assets are listed in `data/visual_catalog.tres`; missing optional Walker sheets fall back to the procedural avatar without changing gameplay geometry.

## Develop

```bash
$HOME/bin/godot --path .
./verify.sh
```

`verify.sh` includes a Python batch gate that decodes all eight primary and alternate biome Ogg files, checks their cyclic waveform boundaries, and asks Godot to seek each imported stream across its loop point. Run that gate directly when iterating on music assets:

```bash
python3 test/test_bgm_loops.py --godot "$HOME/.local/bin/godot"
```

For a clean no-threads Web release:

```bash
./verify.sh --release
```

The release command writes HTML, JavaScript, WASM, and PCK artifacts to `/home/ubuntu/proto-isometric-build/web`.

## Project references

- [Implementation plan](docs/plans/WALKERS_WAKE_IMPLEMENTATION_PLAN.md)
- [Gameplay proposal](docs/concept/gameplay-v2/GAMEPLAY_ENHANCEMENT_PROPOSAL.md)
- [Walker sprite contract](assets/walker/SOURCES.md)
- Source: https://github.com/junnyboi/proto-isometric
