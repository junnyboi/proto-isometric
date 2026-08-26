# Protos Harvest
## Fully Inspectable and Interactable World Implementation Plan

**Author:** Manus AI  
**Engine:** Official Godot 4.7.2 stable, GL Compatibility  
**Canonical branch:** `main`; fast-forward synchronization, no history rewriting  
**Baseline revision:** `db833ad391193e7c94bd0063a712076f133fabb0`  
**Deployment:** Existing `proto-isometric-web` WebDev project, fullscreen iframe only  
**Companion proposal:** [Fully Inspectable and Interactable World Proposal](PROTOS_HARVEST_INSPECTABLE_WORLD_PROPOSAL.md)

## 1. Mission and completion definition

Implement a deterministic, localized, responsive read path that makes every stable interaction target meaningfully inspectable, closes all operation-routing gaps, preserves existing productive actions, and enables only those new world actions that can meet the repository's atomicity and reload guarantees.

The implementation is complete only when:

1. Terrain → Inspect produces a useful current-state Decision Card instead of `preview_only`.
2. Every emitted provider-operation pair has exactly one closed authority route.
3. Every stable projected target family has a useful localized read result.
4. Existing productive actions retain their IDs, costs, arguments, close behavior, stale checks, transaction authority, and exact-once behavior.
5. Stable pond/water, safe exit, and functional props are inspectable without adding resolver kinds.
6. Pickup, hazard, and transition actions are enabled only where atomic adapters pass retry/reload tests; otherwise they remain truthfully disabled.
7. Native, Web export, served-browser, responsive, accessibility, localization, persistence, performance, and WebDev deployment gates pass.

## 2. Immutable constraints

| Concern | Constraint |
|---|---|
| Engine and format | Stay on Godot 4.7.2 stable and the existing project format. |
| Spatial authority | Keep the current adjacent resolver, ten target kinds, masks, and priority. |
| Existing contracts | Do not alter the exact keys of target, option, menu, or resolver results. |
| Save model | Inspection adds no persisted section, migration, discovery cache, history, or UI state. |
| Read purity | Reads change no save, revision, receipt, ledger, RNG, resource, dirty cell, node, or tutorial persistence. |
| Mutation authority | Existing farm, cross-domain, construction, deposit, run, and world services remain authoritative. |
| Quick | Remains mutation-only; Inspect and review actions remain ineligible. |
| UI ownership | Extend the one pooled native presenter; no second modal or DOM overlay. |
| Localization | Contracts contain keys and primitive values, never translated prose. |
| Web | No threads, native plugins, dynamic loading, filesystem-dependent reads, or per-frame projection. |
| Version control | After each completed phase: run focused and regression checks, update this completion record, commit, and push `main` without rewriting history. |

## 3. Architecture deliverables

### 3.1 `InteractionOperationCatalog`

A new static `RefCounted` catalog classifies every stable operation. Each exact descriptor contains:

```gdscript
{
    &"operation": StringName,
    &"route": StringName,                 # read | farm | cross_domain | construction_ui | world_runtime
    &"adapter_id": StringName,
    &"allowed_provider_ids": Array[StringName],
    &"mutability": StringName,            # read_only | ui_only | mutating
    &"receipt_policy": StringName,        # none | required | postcondition_idempotent
    &"persistence_domains": Array[StringName],
    &"stale_policy": StringName,          # snapshot_identity | snapshot_and_revision
    &"allowed_close_behaviors": Array[StringName],
}
```

Catalog validation rejects duplicate operations, unknown routes, empty provider sets, unsorted providers/domains, read descriptors with persistence or receipts, mutating descriptors without persistence, invalid close behavior, and unreachable descriptors. Provider-fixture closure tests enumerate all emitted options.

### 3.2 `InteractionExecutionResult`

A new exact ten-key transient result:

```gdscript
{
    &"result_id": StringName,
    &"ok": bool,
    &"reason_key": StringName,
    &"mutated": bool,
    &"source_snapshot_id": StringName,
    &"action_id": StringName,
    &"target_id": StringName,
    &"target_cell": Vector2i,
    &"observed_state": Dictionary,
    &"view": Dictionary,
}
```

The result validates existing codec budgets and a twelve-fact view cap. `result_id` is a deterministic digest of the canonical other nine fields. `mutated` implies semantic success and a mutating descriptor. Reads and UI transitions reject `mutated = true`.

The exact view grammar is:

```gdscript
{
    &"title_key": StringName,
    &"body_key": StringName,
    &"parameters": Dictionary,
    &"facts": [
        {
            &"label_key": StringName,
            &"value_kind": StringName, # text_key | integer | decimal | boolean | identifier
            &"value": Variant,
        }
    ],
}
```

### 3.3 `InteractionReadResultCatalog`

A pure static catalog builds a read result from a freshly revalidated menu, current exact option, and validated operation descriptor. It includes explicit branches for the supported operation/subkind matrix and a safe generic fallback. It never queries nodes, reads or writes a save, accesses time or RNG, runs a transaction, or emits a callback.

### 3.4 Existing component changes

| Existing component | Change |
|---|---|
| `HarvestInteractionController` | Remove Inspect bypass; delegate every enabled row once; validate common results; emit mutation commit only when `mutated`; preserve stale refresh and close behavior. |
| `HarvestInteractionPhaseBService` | Rebuild fresh menu plus exact option; validate operation/provider closure; dispatch by route; wrap existing outcomes; never fall through an unknown operation to farm runtime. |
| Providers | Add only bounded authoritative fields needed by cards; normalize operation IDs at emission source. |
| `HarvestInteractionPresenter` | Add pooled detail rows, Details/Actions modes, localization, focus ownership, touch Back/Activate, responsive layout, accessible result semantics. |
| Map/world discovery | Add stable water, exit, and functional-prop subkinds through existing coarse kinds. |
| Existing mutation services | Add narrow adapters only when a missing productive seam can meet atomicity and retry requirements. |

## 4. Phased work packages

## Phase 0 — Baseline, characterization, and plan certification

### WP0.1 Synchronize and freeze baseline

- Verify the canonical repository, protect uncommitted work, fetch/prune, and fast-forward `main`.
- Inspect `project.godot`, README, export preset, and test manifests.
- Restore official Godot 4.7.2 and matching no-threads templates.
- Record the baseline source revision and WebDev mapping.

### WP0.2 Characterize the defect

Add or identify focused assertions proving that:

- Terrain projects an enabled Inspect row.
- Opening the terminal is non-mutating.
- Confirming Inspect currently returns `preview_only`.
- The presenter currently renders no structured facts.
- No existing productive action depends on the Inspect bypass.

The characterization is temporary or inverted in Phase 1; it must not fossilize incorrect behavior.

### WP0.3 Preserve baseline regressions

Run interaction Phase A/B/C, construction, deposits, settlement, localization, persistence, smoke, import, lint, and bounded boot. Record exact test counts.

### WP0.4 Proposal and concept package

Commit the gameplay proposal, this plan, and three GPT Image 2 concepts. The runtime must use native controls and existing art direction; generated mockups are references, not flattened interface assets.

### Phase 0 exit gate

- Baseline tests pass at synchronized revision.
- Root cause is demonstrated.
- Proposal, plan, and concepts are reviewable from the repository.
- No runtime behavior has changed.
- Completion record is updated and pushed to `main`.

## Phase 1 — Terrain vertical slice and common result path

### WP1.1 Implement the three core contracts

Add `interaction_operation_catalog.gd`, `interaction_execution_result.gd`, and `interaction_read_result_catalog.gd` with exact-key validators, canonical builders, deterministic digests, caps, and fail-closed behavior.

Initial operation closure includes at least the generic Inspect row and all operations needed to preserve existing terrain mutations. Catalog design must be complete enough that no temporary second router is introduced.

### WP1.2 Enrich terrain projection

Pass a bounded terrain descriptor into the farm provider. At minimum expose stable keys for:

- surface and biome;
- walkability;
- authoritative tillability/farmability;
- blocker/occupant class;
- plot state;
- crop ID, stage, water state, and readiness where applicable.

Do not query world nodes from the provider. Derive each field from the authority already used by world or farm rules.

### WP1.3 Generalize controller confirmation

- Remove `option.operation != inspect` special handling.
- Delegate every enabled option once through the existing callback.
- Validate the returned common result.
- Emit `menu_execution_result` for reads and mutations.
- Emit `safe_menu_action_committed` only for `mutated = true`.
- Preserve `_executing`, identity re-resolution, stale refresh, selection, and close behavior.

### WP1.4 Add fresh Phase B read dispatch

Replace the option-only lookup with a fresh current menu/option pair. Validate target identity, exact option equality, descriptor/provider compatibility, and stale policy. Route generic Inspect to the read catalog. Existing terrain mutations keep their current transaction branches and are wrapped without changing authoritative result semantics.

### WP1.5 Render the first Decision Card

Extend the presenter minimally with a bounded detail area and fixed fact-row pool. Terrain Inspect renders localized identity, state signals, consequence, and next steps. The menu remains open under `CLOSE_NEVER`. Locale switching rerenders from stored canonical data.

### WP1.6 Focused tests

- Result exact keys, invariants, malformed values, caps, and digest.
- 1,000 shuffled dictionary-order determinism iterations.
- Terrain, plot, watered crop, growing crop, and ready crop card fixtures.
- Walkable-but-not-tillable distinction.
- Stale first confirmation refreshes with zero execution; second read binds fresh snapshot.
- Read changes no save bytes, revisions, receipts, ledger, RNG, resources, dirty cells, callbacks, or nodes.
- Inspect remains Quick-ineligible.
- Existing till/plant/water/harvest byte outcomes remain unchanged.

### Phase 1 exit gate

Terrain → Inspect returns a validated non-empty localized result with `mutated = false`, never displays Preview Only, remains open, is current-snapshot-bound, and performs no persistent or mutation side effects. Focused and aggregate regressions pass; completion record is updated and pushed.

## Phase 2 — Current-provider read closure and complete modal UX

### WP2.1 Close operation routing

Enumerate every provider fixture and register each emitted operation/provider pair. Correct operation drift at emission source, including threat review naming. Register `inspect_deposit` and `inspect_construction` as reads. Unknown operations fail with a localized unrouted reason and never enter farm runtime.

### WP2.2 Implement all current read adapters

Add explicit cards for:

- home, storage, shipping, facilities, machines;
- residents and livestock;
- construction lifecycle, range, worker, upgrade state;
- finite salvage, mineral, and managed biomass deposits;
- trees, legacy resources, pickups;
- herds, hostiles, hazards, ruins, and gates;
- specialized inventory, storage, shipping, machine progress, relationship, service, threat, drop, habitat, forecast, mitigation, sanctuary, first-clear, and gate review operations.

Cards must reference current sealed options for next steps rather than recomputing eligibility.

### WP2.3 Complete result wrapping for existing mutations

Wrap existing farm, cross-domain, deposit, and construction UI outcomes in the common result. `mutated` becomes true only after the existing authority's commit point. Candidate envelopes, receipts, and arbitrary transaction dictionaries never enter the presenter result.

### WP2.4 Complete modal UX

- Wide landscape: bounded Details and Actions regions.
- Compact/portrait: Details and Actions tabs.
- Explicit terminal-owned touch Back and Activate.
- Back returns from Details to Actions before closing.
- Keyboard/controller focus trap and restore.
- Shared intentional-input modality formatting.
- Duplicate activation suppression.
- At least 44-pixel targets and two visible action rows where possible.
- Color-independent state glyph/text and accessible fact descriptions.

### WP2.5 Localization closure

Add exact English/Simplified Chinese parity for every result title, body, fact label, enumerated value, failure, tab, binding, and accessibility description. Reject `preview_only`, missing-key markers, prelocalized provider prose, and humanized internal IDs.

### WP2.6 Focused tests

- Exhaustive emitted-operation closure and reachability.
- Every current stable target family produces a valid card.
- Every read is mutation-free and storage-independent.
- Locale switching preserves `result_id`, target/action identity, and selection.
- 1/8/32 actions, both handedness modes, scales 0.85/1.0/1.25, English/Chinese.
- Viewports: 1280×720, 1024×576, 844×390, 720×1280, 390×844, 320×320.
- Keyboard, mouse, controller, and touch ownership; focus restore; duplicate input.
- Repeated open/read/back/locale/close cycles preserve one presenter and bounded pools.

### Phase 2 exit gate

Every currently projected stable target and read row returns a validated localized card; every emitted operation has one route; no read reaches persistence; the complete modal works across inputs, locales, accessibility settings, and certified viewports. Regressions pass; completion record is updated and pushed.

## Phase 3 — Stable target discovery closure

### WP3.1 Water and pond targets

Use existing world authority to project stable pond or water-edge cells under an existing coarse resolver kind. Card fields may include water class, traversal, irrigation relevance, and available existing actions. No fishing or sampling system is invented unless an authority already exists.

### WP3.2 Safe exit and transition targets

Project stable safe-exit cells with current destination/readiness/risk state. Inspection is enabled immediately; transition remains disabled until Phase 4 authority certification where needed.

### WP3.3 Functional props

Project only props with stable identity and gameplay-relevant state. Decorative draw elements remain excluded. Cards explain purpose, status, and existing next steps.

### WP3.4 Fixed-cell taxonomy tests

Certify representative cells for terrain, plot, crop, water, tree, resource, all deposit types, home domains, construction, residents, livestock, ruin, gate, exit, functional prop, pickup, herd, hostile, and hazard. Each cell resolves exactly one expected target/provider according to current priority.

### Phase 3 exit gate

Every stable intentionally interactable feature resolves predictably and has a useful card without changing resolver kinds or priority. Decorative exclusions are documented. Regressions pass; completion record is updated and pushed.

## Phase 4 — Productive world seam closure

Each work package is independently gated. A row changes from disabled to enabled only after its adapter passes all tests.

### WP4.1 Pickup collection

Implement atomic collection for run pickups and/or world scrap using existing run/world and farm authorities. Stable identity and cell are revalidated. Durable state and reward commit together. Node removal publishes only after commit. Full inventory, stale identity, save failure, duplicate retry, and reload leave one exact outcome.

### WP4.2 Hazard stabilization

Join the current hazard event snapshot to a pure candidate carrying hazard removal, capability/reward, and relevant persistence domains. Enable only when the commit point cannot report retryable failure after durable success. Otherwise retain a localized disabled explanation.

### WP4.3 Gate and safe-exit handoff

Use existing run/scene lifecycle authority for deterministic transition. Any run mutation commits before transition publication. Inspection never changes first-clear or run state. Unsupported remote-ruin activation remains deferred to expedition return.

### WP4.4 Retry and capacity policy

If broader exact-once receipts are required, implement and separately certify deterministic capacity/retirement policy before enabling the action. Do not silently enlarge ledger budgets. If a durable postcondition proves idempotence without a receipt, document and test it explicitly.

### WP4.5 Seam tests

For each newly enabled operation:

- success;
- disabled prerequisite;
- stale target/revision;
- invalid arguments;
- candidate validation failure;
- save/publish failure;
- duplicate replay;
- token conflict where relevant;
- reload recovery;
- no node removal without durable state;
- no reward without corresponding world/run mutation;
- no partial close/result/tutorial commit.

### Phase 4 exit gate

Every newly enabled productive seam is atomic, stale-safe, retry-safe, and reload-safe. Unsupported seams remain honestly disabled. Regressions pass; completion record is updated and pushed.

## Phase 5 — Release certification and deployment

### WP5.1 Final source synchronization

Fetch/prune and fast-forward or merge upstream without rewriting history. Resolve concurrent changes, rerun all focused checks, and push the final source candidate.

### WP5.2 Full Godot gate

Run:

- exact engine bootstrap verification;
- direct import;
- repository lint;
- all focused runners and aggregate smoke;
- bounded headless boot;
- clean script/resource/renderer/fatal log scans;
- `verify.sh --release`;
- exact exported-PCK independent boot.

### WP5.3 Performance and lifecycle

Measure on representative native/headless Web fixtures:

- projection P95 <2 ms and P99 <4 ms;
- read construction P95 <2 ms and P99 <4 ms;
- confirm-to-visible read P95 <16.67 ms and P99 <33.33 ms;
- no per-frame card construction;
- one presenter/reticle and bounded pooled controls;
- no target nodes, signal leaks, or idle dirty rendering.

### WP5.4 Native visual verification

Use Xvfb with dummy audio. Exercise representative Context, Inspect, Details/Actions, productive confirmation, Cancel/Back, movement, Tool, and Smash. Inspect landscape and portrait screenshots for terrain, crop, machine/construction, resident/livestock, deposit, hostile/hazard, water/exit, and result feedback.

### WP5.5 Served Web verification

Require HTML, JavaScript, WASM, and PCK plus declared worklets/icons/loader assets. Serve over HTTP. Verify MIME and status, title-ready/field-ready, menu and inspection interaction, mutation refresh, landscape/portrait resize, persistent/volatile/blocked storage behavior, network resources, runtime console, and no cross-origin failures.

### WP5.6 WebDev refresh

Reuse `proto-isometric-web`. Refresh storage-backed large runtime payloads and same-origin small loader/worklet files. Keep only a dynamic borderless zero-margin fullscreen iframe. Update `PLAN.md`, `STRUCTURE.md`, `MEMORY.md`, and `ASSETS.md`; run Vitest, TypeScript, production build, preview, desktop and portrait visual checks; save a final checkpoint and publish when the deployment tool is available.

### Phase 5 exit gate

The exact source revision and hosted payload pass all native, exported-PCK, HTTP browser, responsive, accessibility, localization, persistence, storage-mode, performance, WebDev build, checkpoint, and publish gates.

## 5. Acceptance matrix

| Category | Required evidence |
|---|---|
| Contracts | Exact keys, malformed rejection, codec caps, twelve-fact cap, 1,000-order deterministic digest |
| Routing | Every emitted provider-operation pair maps once; every descriptor is reachable; unknown operations fail closed |
| Terrain | Useful distinct cards for untouched, tilled, watered, growing, ready, blocked, walkable/non-tillable states |
| Current world | Useful cards for all current farm, homestead, social, livestock, construction, deposit, wilderness, hazard, ruin, and gate families |
| Discovery | Stable water, safe exit, and functional props use subkinds; decorative-only elements excluded |
| Read purity | No save/revision/receipt/ledger/RNG/resource/tutorial/dirty/publication/node changes |
| Mutations | Existing byte behavior preserved; new seams atomic, retry/reload safe, and authority-owned |
| UI | One presenter; bounded pools; wide split and compact tabs; focus and touch controls; no leaks |
| Localization | Exact en/zh-CN key and placeholder parity; no missing keys, raw IDs, or `preview_only`; catalogs under budget |
| Accessibility | 44-pixel controls, keyboard/controller/mouse/touch parity, handedness, scale, non-color semantics, reduced effects |
| Compatibility | Existing saves, expedition behavior, Quick, Tool, Smash, target diamond, construction, deposits, and home loop remain protected |
| Release | Import, lint, smoke, bounded boot, release export, exact PCK boot, HTTP browser, WebDev build/checkpoint/publish |

## 6. Planned source inventory

### New core files

- `scripts/interaction_operation_catalog.gd`
- `scripts/interaction_execution_result.gd`
- `scripts/interaction_read_result_catalog.gd`
- optional focused `test/test_interaction_inspection.gd` and runner if existing phase files would exceed maintainable size

### Primary modified files

- `scripts/harvest_interaction_controller.gd`
- `scripts/harvest_interaction_phase_b_service.gd`
- `scripts/harvest_interaction_presenter.gd`
- `scripts/harvest_interaction_farm_provider.gd`
- `scripts/harvest_interaction_world_provider.gd`
- `scripts/construction_interaction_provider.gd`
- `scripts/resource_deposit_interaction_provider.gd`
- `scripts/harvest_map_bridge.gd`
- `data/locales/en.json`
- `data/locales/zh-CN.json`
- `export_presets.cfg`

### Conditional Phase 3/4 files

- `scripts/infinite_world.gd`
- `scripts/woodland_clearing.gd`
- `scripts/ironjaw_desert_arc.gd`
- existing run, hazard, transition, world mutation, and cross-domain authorities only where atomic seam integration requires them

### Focused tests

- interaction Phase A/B/C suites
- construction and deposit suites
- settlement Phase 1–5 suites
- localization, field UI, accessibility, HUD, contracts, performance, persistence, and smoke suites

## 7. Risk register

| Risk | Mitigation |
|---|---|
| Stale or misleading card | Build only from the fresh service-reprojected menu; bind result digest to `source_snapshot_id`. |
| Presenter becomes gameplay authority | Presenter consumes validated localized descriptors only; no provider/node queries or eligibility recomputation. |
| Read accidentally mutates | Closed route catalog, mutation flag invariant, byte/revision/receipt/ledger purity tests. |
| Operation list drift | One operation catalog and exhaustive provider-fixture closure test. |
| Raw ID or untranslated state leaks | Explicit catalog projection; observed state never rendered; release rejection tests. |
| Mobile content overflow | Fixed pools, Details/Actions tabs, one scroll owner, reserved controls, certified minimum viewport. |
| Walkability confused with farmability | Use separate owning authorities and fixed walkable-but-not-tillable tests. |
| New action partially commits | Keep disabled until candidate, persistence, publication, retry, and reload tests pass. |
| Receipt ledger exhaustion | Do not broaden receipt usage without separately certified capacity policy. |
| Concurrent agents change main | Re-fetch before every phase gate and final export; merge without rewriting history. |
| Scope expands into a world rewrite | Preserve resolver, save schema, movement, combat, camera, ecology, renderer, Quick, and existing balance. |

## 8. Completion record

This record must be updated after each phase with the source revision, implemented work packages, test counts, visual findings, Web status, commit, and push outcome.

| Phase | Status | Revision | Evidence |
|---|---|---|---|
| Phase 0 | Complete | `db833ad391193e7c94bd0063a712076f133fabb0` | Architecture audited; proposal, plan, and three GPT Image 2 concepts prepared. A concurrent combat-tuning update was integrated without rewriting history. Godot 4.7.2 baseline passed interaction A **14/14**, interaction B **16/16**, interaction C **18/18**, settlement four **39/39**, settlement five **27/27**, aggregate smoke **2,110/2,110**, direct import, repository-wide lint, BGM loop validation, and bounded title boot with clean error scans. The planning package is included in this phase commit and push. |
| Phase 1 | Complete | Included in the Phase 1 implementation commit | Added a closed 57-operation catalog, exact ten-key result envelope, pure bounded read catalog, authoritative terrain descriptors, common controller result handling, sealed-target confirmation, selected-tool revalidation, and a fixed twelve-row Decision Card pool. Integrated canonical workforce Phase Six and title feedback without weakening mutation staleness. Passed inspection contracts **13/13** including 1,000 shuffled builds, interaction A **14/14**, interaction B **17/17**, interaction C **19/19**, settlement Phase Five **27/27**, settlement Phase Six **32/32**, aggregate smoke **2,135/2,135**, direct import, repository-wide lint, bounded boot, and clean 1280×720 plus 720×1280 native Inspect captures. |
| Phase 2 | Complete | Included in the Phase 2 implementation commit | Closed every current read route across **20** target families and **22** registered read operations; removed the unreachable `read_threat` alias; added authoritative home/storage occupancy summaries; made stewardship settlers directly inspectable; and delivered bilingual bounded facts for farm, social, wilderness, construction, deposit, and expedition targets. Compact viewports now use Details/Actions tabs with terminal-owned 44-pixel Back/Activate controls, two-step Back behavior, focusable controls, and duplicate activation suppression while wide layouts retain simultaneous Details and Actions. Passed inspection contracts **18/18**, interaction A **14/14**, interaction B **17/17**, interaction C **21/21**, settlement four **39/39**, settlement five **27/27**, settlement six **32/32**, aggregate smoke **2,140/2,140**, repository-wide lint/import/boot gates, and clean 1280×720 plus 720×1280 native visual checks. |
| Phase 3 | Pending | — | Stable water, exit, and functional-prop discovery. |
| Phase 4 | Pending | — | Atomic productive seam closure. |
| Phase 5 | Pending | — | Full native/Web certification and WebDev deployment. |
