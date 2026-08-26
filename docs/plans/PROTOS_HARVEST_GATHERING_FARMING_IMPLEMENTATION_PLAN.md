# Protos Harvest
## Gathering, Harvest, and Farming Implementation Plan

**Baseline:** `2ab6d6c785db32a233919863019291556c89bd89`
**Engine:** Godot 4.7.2 stable
**Delivery:** canonical `main` → verified Web export → existing `proto-isometric-web` WebDev project

## Phase 1 — Catalogs and production assets

| ID | Work | Exit condition |
|---|---|---|
| `GF-01` | Add five stable item pairs for seed and produce/material output. | Item catalog validates unique IDs, stack limits, and prices. |
| `GF-02` | Add five crop definitions with four stages, yield, growth, and regrowth. | Crop catalog validates, schema accepts records, and existing six crops remain exact. |
| `GF-03` | Generate and prepare five four-stage atlases with GPT Image 2. | Runtime sheets are 1024 × 256 RGBA, bottom-anchored, registered, and Web-exported. |
| `GF-04` | Add a pure wild flora catalog. | Definitions expose canonical spawn, reward, crop, and texture data. |

## Phase 2 — Deterministic wild ecology

| ID | Work | Exit condition |
|---|---|---|
| `GF-05` | Add coordinate-derived wild flora generation. | Same seed/cell always returns the same species; bounded density tests pass. |
| `GF-06` | Integrate terrain, structure, tree, rock, deposit, farm, and path exclusions. | Flora never overlaps protected or occupied cells. |
| `GF-07` | Extend mutation ledger with `object.flora`. | Cleared flora survives save/load and legacy arrays remain exact. |
| `GF-08` | Batch-draw wild flora from mature atlas frames. | No per-flora nodes; stream order and depth are stable. |

## Phase 3 — Atomic gathering and interaction

| ID | Work | Exit condition |
|---|---|---|
| `GF-09` | Add flora Context projection and canonical reward preview. | Inspect and Smash offers resolve to the exact adjacent flora identity. |
| `GF-10` | Add cross-domain flora clear/reward transaction. | Produce, seed, and cleared mutation commit atomically; failures roll back. |
| `GF-11` | Intercept Smash before ordinary combat/rock resolution. | Existing attack animation triggers flora harvest; other targets retain current behavior. |
| `GF-12` | Add harvest audio/status/dirty-cell presentation. | Wild plant disappears immediately after acknowledgement and produces bounded feedback. |

## Phase 4 — Seed-to-harvest farming loop

| ID | Work | Exit condition |
|---|---|---|
| `GF-13` | Register new crops with existing owned-seed planting menus. | Acquired seeds appear only when owned and consume exactly one on planting. |
| `GF-14` | Validate watering and dawn growth for all species. | Unwatered crops pause; watered crops reach canonical stages. |
| `GF-15` | Validate full-yield harvest and regrowth. | Starflower, wheat, and cotton clear; brambleberry and sunpear regrow at declared thresholds. |
| `GF-16` | Add localization and result copy. | English and Simplified Chinese placeholder parity passes. |

## Phase 5 — Verification and deployment

| ID | Work | Exit condition |
|---|---|---|
| `GF-17` | Add unit, schema, determinism, transaction, renderer, and regression contracts. | Targeted and full smoke suites pass. |
| `GF-18` | Run direct import, 120-frame boot, and dual-aspect Xvfb interaction. | No errors; wild gather and farm loop are visually legible. |
| `GF-19` | Run full release and exported-PCK gates. | HTML, JS, WASM, PCK, loader art, and PCK boot pass. |
| `GF-20` | Re-fetch upstream, integrate, retest, commit, and push `main`. | Shared default branch advances without rewriting history. |
| `GF-21` | Refresh the existing `proto-isometric-web` host and save a checkpoint. | Type/build tests, served runtime, console/network scan, landscape/portrait checks, and live farming interaction pass. |

## Regression matrix

| Domain | Required regression |
|---|---|
| World generation | Existing biome goldens, tree belt, gates, paths, pond, home, resource deposits, and construction occupancy remain unchanged. |
| Persistence | Schema 1–4 fixtures, world ledger ordering, save caps, revisions, rollback, and exact-once receipts remain valid. |
| Combat | Hostile and rock Smash behavior remains unchanged when no flora occupies the target. |
| Farming | Existing six crops retain growth, yield, texture, shipping, and seed-shop semantics. |
| Rendering | Visible-cell and chunk indexes stay bounded; no new per-entity nodes or idle redraw loops. |
| Interaction | Resolver priority, stale identity, modal input quarantine, keyboard/controller/touch parity, and Context safety remain intact. |
| Web | No file-scheme loading; storage-backed PCK/WASM, worklet routing, MIME/range behavior, console, and network logs remain clean. |

## Implementation result

**Status: completed end to end.** GF-01 through GF-21 were implemented in the canonical repository and the release harness now permanently runs the dedicated interaction Phase B suite. The final source candidate passed **2,158 general smoke assertions**, **27 Phase B integration assertions**, including four new GF lifecycle contracts, a direct 120-frame headless boot, deterministic live Smash gathering, native 1280 × 720 and 720 × 1280 visual checks, Web export generation, and exported-PCK boot.

The production art implementation uses five four-stage 1024 × 256 atlases for cultivated crops and five exact 256 × 256 mature-frame derivatives for wild rendering. Native verification exposed a compressed-texture alpha artifact during development; the shipped renderer therefore reconstructs mature specimens as cached RGBA `ImageTexture` objects. This preserves transparent botanical silhouettes without per-flora scene nodes in both desktop and portrait rendering.

Discovery-derived seeds carry the `wild_discovery` trait and are intentionally excluded from the baseline greenhouse seed shop. They become plantable automatically when the atomic wild-harvest transaction credits ownership. Brambleberry and Sunpear use the existing regrowth authority; Starflower, Wildwheat, and Cotton clear after harvest.
