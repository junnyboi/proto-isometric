# Protos Harvest Concept Dossier Phase 0 Baseline

**Author:** Manus AI, Agent 4
**Canonical baseline:** `8e0d04f19dd60558d7b4d6d65bc7e227d5d30f46`
**Engine:** Godot `4.7.2.stable.official.ed1daf0bf`
**Date:** 2026-08-27

## Purpose

This report freezes the verified source, interaction, visual, and Web-export baseline before implementing the concept-faithful interaction dossier. The three supplied concepts remain design references only and are not runtime textures. The default-off project setting `features/interaction_dossier_v2=false` was added without activating a runtime path.

## Verification results

| Gate | Result |
|---|---|
| Canonical synchronization | `main` fast-forwarded to `8e0d04f19dd60558d7b4d6d65bc7e227d5d30f46` before the final Phase 0 release gate |
| Godot compatibility | Project remains Godot 4.7 GL Compatibility; official 4.7.2 engine and matching no-threads Web templates used |
| Aggregate verification | `[SMOKE_PASS] checks=2142`; `[PASS] Protos Harvest` |
| Release verification | `[PASS] Protos Harvest --release`; exported PCK boot emitted `[PCK_BOOT_PASS]` |
| Golden settlement schedule | 1,000 days; SHA-256 `162fc7dec14149a3ea7beb67007b8be8cc474a310ecd87cacee19061b4f37270` |
| Interaction inspection | `[INTERACTION_INSPECTION_PASS] checks=19` |
| Interaction Phase C | `[HARVEST_INTERACTION_PHASE_C_PASS] checks=21` |
| Xvfb representative input | Landscape and portrait title/field/terrain, pond, and facility interaction captures passed |
| Locale baseline | English and Simplified Chinese remain exact-key paired in the existing suite |
| Runtime behavior delta | None; the new feature flag is default-off and has no consumer in Phase 0 |

The release log retains one pre-existing nonfatal Godot warning about loading `kilnheart_idle.png` as an image file. Export and exported-PCK boot still passed; the warning is unrelated to the dossier work and is not relaxed by this implementation.

## Web release artifact baseline

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `proto-isometric.html` | 7,853 | `35b88e9603fec3e66fd62f7d6396fd8c78946f770b44603b416df79a58c92351` |
| `proto-isometric.js` | 279,815 | `33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba` |
| `proto-isometric.wasm` | 39,514,754 | `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |
| `proto-isometric.pck` | 73,960,420 | `3dfa7f68150d274187b521a1a979b4655e73bf4a3b6373592a9672058390321f` |
| Desktop loader WebP | 197,432 | `f3384c18c881676556c0954f2e3f8e8a9d19ccfcd36ee222ce84f8d5edb0ad77` |
| Mobile loader WebP | 195,974 | `4e3a0fdc6186b1224989ecb2d8f0c622841c5d780e545923aa3d24e5743e234a` |

## Visual baseline

| Capture | SHA-256 | Baseline observation |
|---|---|---|
| Landscape terrain Inspect | `bd79f0bacf9a4da99ba81cba695bff5fcbce0df943051a344f94a9240f9183dd` | Truthful flat fact card and action list; no illustrated dossier, coordinate header, detached preview, POI card, or connector overlay |
| Portrait terrain Inspect | `cbf5c87948ff2dfc4aa4f9a0667e9ff7565f38430c296a41145e8698483aee73` | Tall left panel occupies nearly the full height; no world-preserving Summary/Actions/History bottom sheet |
| Landscape pond Inspect | `3bb54b0506e28cbbce10174853a24193a6436f0fb9b221e7f199d81a06e5b908` | Truthful Freshwater Pond, Walkable No, Irrigation Relevant Yes; canonical fishing rows are present with real lock reasons |
| Portrait pond Inspect | `185d0252a74100680f7be54aa986d6cc47c244d1ba584bc7a392c94ee0312809` | Same truthful water/fishing authority, but the portrait composition remains the tall side terminal |
| Landscape facility Inspect | `34132f3a234b67dd37981759a54453003dccd191bf114b4d8dbd542db8d919ca` | Canonical Facility Terminal reports Repaired No, Powered No, exact Repair Facility costs, and a truthful Restore Power lock |
| Portrait facility Inspect | `9ecf8f90a8735e91e473a2873c4d9eaf7c7d36ab81f7939bb1cf2c389a2fa128` | Truthful object state, but no object portrait, grouped status hierarchy, right results pane, or bottom-sheet adaptation |

The current UI already preserves the important mechanical floor: one pooled presenter, sealed target identity, stale rejection, disabled-row safety, select-then-confirm, modal suppression, and bounded fact/action pools. The recreation must improve hierarchy without replacing those authorities.

## Performance and allocation floor

The baseline suites certify unchanged HUD construction skips, radar redraw skips, stationary static-object redraw skips, pooled transient effects, one live `HarvestInteractionPresenter`, no per-target world-node growth across open/close cycles, a fixed twelve-row Decision Card pool, and duplicate activation executing once. Phase-specific dossier counters and open/steady timing are introduced in later phases and compared to this structural floor plus the release artifact sizes above.

## Commands

```bash
GODOT="$HOME/.local/bin/godot" PATH="$HOME/.venvs/godot-tools/bin:$PATH" ./verify.sh
GODOT="$HOME/.local/bin/godot" PATH="$HOME/.venvs/godot-tools/bin:$PATH" ./verify.sh --release
GODOT="$HOME/.local/bin/godot" /home/ubuntu/run-proto-isometric-visual-check.sh
GODOT="$HOME/.local/bin/godot" /home/ubuntu/run-proto-isometric-pond-check.sh
GODOT="$HOME/.local/bin/godot" /home/ubuntu/run-proto-isometric-facility-check.sh
```

## Phase 0 conclusion

The baseline is green after integrating the concurrent gathering/farming release, and the discrepancy is now measured rather than aesthetic guesswork. The most urgent visual defect is the portrait terminal’s full-height left column; the highest correctness risk is copying concept-only telemetry into player-facing UI. Phase 1 may proceed with pure presentation contracts while the dossier feature remains disabled.
