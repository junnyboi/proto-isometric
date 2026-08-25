# Protos Harvest
## Universal Interaction Implementation Plan

**Engine:** Official Godot 4.7.2 stable, GL Compatibility  
**Branch policy:** Fast-forward-only `main`; regression test and push after every completed phase  
**Deployment:** Existing `proto-isometric-web` WebDev project, fullscreen iframe only

## 1. Immutable constraints

The implementation must preserve all existing command IDs, schema-4 keys, schema-1/2/3 migration meanings, stable runtime IDs, `user://walkers-wake-world.json`, deterministic day ordering, exact-once tokens, legacy expedition behavior, home safety, node-free world presentation, Godot 4.7.2, GL Compatibility, and the no-threads Web export.

The highlighted adjacent tile remains the sole spatial authority. Opening E is preview-only. Productive selection is revalidated against current committed state and uses one existing transaction boundary. Interaction metadata is runtime-only and never enters saves.

## 2. Phase plan

| Phase | Work packages | Exit gate | Push requirement |
|---|---|---|---|
| **A — Contracts and deterministic menu model** | A1–A4 | Focused contract suite, import, lint, existing phase regressions | Push to `main` |
| **B — Universal target/action coverage** | B1–B6 | Catalog-driven coverage, exact-once actions, legacy compatibility | Push to `main` |
| **C — Left-side UI, input ownership, arrow removal** | C1–C6 | Responsive native visuals, modality parity, no-arrow checks | Push to `main` |
| **D — Release, Web export, and deployment** | D1–D5 | Full release/PCK/browser gate and final WebDev checkpoint | Push final certification |

## 3. Phase A — Contracts and deterministic menu model

### A1. Runtime value contracts

Add exact runtime-only validators and builders for `InteractionOption` and `InteractionMenuSnapshot`. An option contains stable action/provider/target IDs, target and subkind, operation, arguments, enabled state, localized label/reason keys, priority, affected cells, cost preview, and close behavior. Arrays are bounded, duplicate IDs reject, and ordering is canonical.

### A2. Target projection

Extend the map bridge target snapshot additively with stable cell-derived or authority-derived identity, subkind, state, and option inputs while preserving the resolver’s existing five-key public result. No scene-node discovery is permitted.

### A3. Deterministic action catalog

Create a pure `InteractionOptionCatalog` that generates and sorts menu options from one highlighted cell. Initial providers cover terrain/plot/crop, tree/resource, pickup, home/facility/ruin, storage/shipping/machine, resident, livestock, wilderness, and legacy expedition targets. Equal state must produce byte-equivalent snapshots regardless of dictionary or registration order.

### A4. Controller lifecycle

Change Context from immediate execution to menu request. Add open/close/confirm/navigation APIs, stale snapshot refresh, selected action identity, pending-tool cancellation, and exact modality parity. Tool contact remains separate and Smash remains untouched.

### Phase A acceptance

- E/A/touch Context produces one sealed menu snapshot and zero mutations.
- All eight facings resolve the existing exact adjacent cells.
- Option ordering remains identical across 1,000 shuffled input orders.
- Invalid, blocked, duplicate, unknown, oversized, and stale data fail closed.
- Existing Phase 0–6 focused suites and full smoke remain green.

## 4. Phase B — Universal target/action coverage

### B1. Terrain, plots, and crops

Expose Inspect, Till, Plant, Water, and Harvest according to plot state, tool, apron/deep-till eligibility, stamina, inventory, and crop catalog. Plant options enumerate all six owned seed types rather than hardcoding Glowroot.

### B2. Trees, resources, and pickups

Expose Inspect, Chop, Mine/Break, and Collect. Axe and Pick compatibility is strict. Completion records one canonical mutation and reward. Full inventory, wrong tool, repeated callbacks, or failed persistence leave world and inventory unchanged.

### B3. Home, facilities, ruins, storage, shipping, and machines

Expose Sleep, Storage, seed purchase, shipping choices, staged value, facility Repair/Power/services, remote ruin inspection, machine Start/Progress/Claim, crafting, and upgrades. Multiple irreversible choices always require row confirmation.

### B4. Residents and livestock

Project stable resident and animal IDs into their current schedule cells. Expose Talk, Gift, Request, Service, Relationship, Feed, Pet, and Product actions. Opening menus never consumes daily tokens. Friendly-fire policy remains absolute.

### B5. Wilderness, hazards, enemies, and bosses

Expose non-destructive threat/habitat/drop inspection, herd Observe/Bond/Yield, hazard forecast/stabilization, gate review/entry, and first-clear progression information. Smash remains the only default hostile damage intent.

### B6. Execution adapters and exact-once behavior

Route every productive menu option to existing farm or cross-domain operations. Revalidate provider/action/target/anchor identity immediately before commit. Publish dirty cells, SFX, and UI only after persistence acknowledgement.

### Phase B acceptance

- Every launch target family yields actions or an explicit noninteractive reason.
- Six crops, four tools, three facilities, two machines, three residents, three livestock species, twelve habitats, four hazards, Ironjaw, remote ruins, and legacy gates are covered.
- Preview and disabled options write nothing and consume nothing.
- Persistence and publish failures restore exact source state.
- Legacy expedition inventory and run-loss policy never touch pre-existing farm inventory.

## 5. Phase C — Left-side UI, input ownership, and arrow removal

### C1. Context dropdown presenter

Create one pooled `CanvasLayer`/`Control` presenter. It shows target title, status, bounded rows, icons, costs, bindings, and disabled reasons. It owns no gameplay authority.

### C2. Input and focus state machine

Implement keyboard, controller, touch, and mouse parity. Opening cancels held movement/tool/Smash input and pending tool contact. Up/Down or D-pad navigates without wrap; E/Enter/Space/A confirms; Escape/B/Cancel/tap-outside closes. Cancel is consumed before the map’s return-to-title fallback.

### C3. Responsive layout and touch exclusions

Anchor the popup to the left safe area; use bounded scrolling on short screens; preserve the joystick, Smash, Settings, farm HUD, and critical reticle. Add popup bounds to touch exclusions and close or deterministically relayout on orientation change.

### C4. Localization and accessibility

Add exact English/Simplified Chinese labels and reasons. Preserve selected action ID across locale refresh. Use label/icon/shape semantics instead of color alone. Respect handedness, reduced effects, haptics, safe areas, and focus accessibility.

### C5. Remove player-foot arrow

Remove the call to `TerrainRenderer.draw_drive_vector` and retire the helper when no tests depend on it. Do not replace it with another player-foot line, arrow, chevron, or dot. Keep Walker facing animation and the highlighted target diamond.

### C6. Visual polish

Use the GPT Image 2 concepts as art direction. Runtime UI uses existing theme colors and font; no generated mockup is embedded as a flat UI image. Verify landscape and portrait native screenshots with tree, farm tile, resident/livestock, building, and hostile-target menus.

### Phase C acceptance

- One opening press never executes an action.
- Second confirmation executes exactly once.
- No foot arrow appears in fresh-farm, legacy, native, PCK, or browser captures.
- Target diamond remains accurate for all eight facings.
- Menu is usable at 1280×720, 1024×576, 844×390, 720×1280, and 390×844.
- English/Chinese key parity and modality parity pass.

## 6. Phase D — Release, Web export, and deployment

### D1. Aggregate test manifest

Run new interaction suites plus all existing phase runners and smoke. Preserve source line caps and reject script/parse/runtime errors.

### D2. Persistence, determinism, and performance

Run save migration fixtures, interruption tests, 1,000-order determinism tests, a mixed multi-day interaction soak, node-count checks, chunk/visible-cell budgets, and idle redraw checks.

### D3. Native and exported-PCK validation

Run direct import, bounded headless boot, repository release script, Web export, HTML/JavaScript/WASM/PCK artifact checks, exact exported-PCK boot, and log error scans.

### D4. Visual and browser verification

Capture landscape and portrait Xvfb frames with representative input. Serve the Web bundle over HTTP, verify `title-ready` and `field-ready`, exercise Context/menu/Tool/Cancel/Smash, inspect network/runtime console, and confirm dynamic fullscreen iframe geometry.

### D5. WebDev refresh

Reuse `proto-isometric-web`, update its four continuity documents, upload large payloads, build, restart, verify, save one final checkpoint, and publish directly only if a publish tool is available.

## 7. Test inventory

| Test category | Required coverage |
|---|---|
| Pure contracts | Exact keys, caps, duplicates, canonical order, stable identity |
| Resolver | Eight facings, priorities, overlap aliases, mode and intent filtering |
| Menu | Open, navigate, confirm, cancel, blocked, stale, locale refresh |
| Atomicity | Validation/write/publish/compensation failures for representative actions |
| Gameplay | All launch target/action families and state transitions |
| Compatibility | Schema 1/2/3/4, fresh farm, legacy active run, expedition return |
| Safety | Seven-day home-boundary soak and friendly-fire matrix |
| Performance | No per-target nodes, bounded offers, dirty-only updates, idle skips |
| Accessibility | Keyboard/controller/touch, left-handed, scale, safe areas, non-color semantics |
| Release | Import, lint, smoke, phase suites, native boot, Web export, PCK boot, browser |

## 8. Deferred scope

Fishing, saplings, breeding, illness, romance, festivals, crop death/quality/fertilizer, machine cancellation, freeform demolition, additional seasons, and new bosses remain deferred. The universal provider/executor/menu architecture intentionally makes these additive future providers rather than reasons to destabilize the launch save schema.

## 9. Completion record

This section will be updated after every implemented phase with revision, focused test counts, regression evidence, visual findings, export status, and WebDev checkpoint.


### Phase A implementation evidence

Phase A is complete. Runtime-only `InteractionOption`, `InteractionTargetSnapshot`, and `InteractionMenuSnapshot` contracts enforce exact ordered keys, bounded collections, stable IDs, canonical nested values, deterministic digests, and fail-closed validation. Nine provider families are registered in canonical order. Context now opens a sealed preview with zero immediate mutation; stale confirmation refreshes and rejects the first accept, navigation is bounded without wrapping, confirmation executes once, Cancel closes without mutation, and opening the menu cancels pending tool contact.

Certification on Godot **4.7.2 stable** passed 14 focused contracts, including all eight facings and 1,000 shuffled input/provider orders; Phase 2 passed 19 checks; Phase 3 passed 24; Phase 6 passed 15; full smoke passed 1,984 checks. Repository-wide GDScript lint, direct import, release verification, Web export, and exact exported-PCK boot all passed. The Web pack explicitly includes all six new Phase A runtime authorities.


### Phase B implementation evidence

Phase B is complete. The live map bridge now delegates resolver projection, sealed menu projection, and productive execution to `HarvestInteractionPhaseBService` whenever the authoritative fresh-farm runtime is active, while retaining the Phase A generic fallback for legacy compatibility. The deterministic farm and wilderness providers cover six crops, four tools, home/storage/shipping, three facilities, workbench and furnace, three residents, three livestock species, twelve ecology habitats, four hazard opportunities, Ironjaw, remote ruins, expedition gates, trees, resource nodes, and pickups. Unsupported live acknowledgements remain visible but disabled with exact reasons rather than reporting false success.

World-object clearing and farm rewards now share one `CrossDomainTransaction` operation. Tree clears persist through the additive mutation ledger, survive reload, suppress regenerated trees, spend stamina, credit the inventory, and reject duplicate application. Legacy rock arrays are synchronized into the same ledger at snapshot time so the existing schema-2 world and all schema-4 save behavior remain exact. Successful cross-domain commits synchronize the live `HarvestFarmRuntime` snapshot before presentation refresh.

Certification on Godot 4.7.2: all GDScript lint and direct import passed; Phase A **14/14**, Phase B **16/16**, Phase 3 **24/24**, Phase 4 **21/21**, Phase 5 authorities **19/19**, Phase 5 presentation **13/13**, Phase 6 **15/15**, and the full regression smoke **1,984/1,984** passed with hidden error scans clean. The explicit Web export filter contains all four Phase B runtime authorities.
