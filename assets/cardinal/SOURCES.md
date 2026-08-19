# Cardinal runtime atlas contract

Cardinal now uses the accepted combined sprite atlas supplied as `grunt_sprite_atlas_godot.zip` on 2026-08-19.

## Runtime files

- `grunt_sprite_atlas.png` — SHA-256 `27287a63ccdc8cff11b788f0c4a25dc66958e43ed84ead383b57cdc6ca64d294`
- `grunt_sprite_frames_builder.gd` — SHA-256 `c755c89bd154d40293b196186d8fbf400ca1aa9f4991be811a7fdddbe565eb48`

The texture is a `6400×4096` RGBA atlas containing sixteen rows and twenty-five `256×256` cells per row. Rows 0–7 are looping `walk_n`, `walk_ne`, `walk_e`, `walk_se`, `walk_s`, `walk_sw`, `walk_w`, and `walk_nw`. Rows 8–15 are non-looping attack animations using the same direction order. Every animation contains twenty-five frames at the authored 12 FPS. Left-facing directions are baked; runtime mirroring is forbidden.

Gameplay impact occurs when the attack enters zero-based frame 11, matching the source package recommendation. The avatar preserves the atlas's centered cells, uses nearest texture filtering, applies one shared runtime scale, and retains a minimal procedural proxy only as a corruption fallback.

The supplied package states that no standalone license grant is embedded. Redistribution remains subject to the asset-license terms held by the game project owner.
