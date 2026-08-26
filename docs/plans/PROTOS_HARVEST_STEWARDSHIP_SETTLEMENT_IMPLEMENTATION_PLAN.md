# Protos Harvest
## Stewardship Settlement Implementation Plan

**Author:** Manus AI  
**Engine:** Godot 4.7.2 stable  
**Branch policy:** complete, certify, commit, and fast-forward push each phase to `main`; never rewrite shared history  
**Deployment policy:** one source repository → existing WebDev project `proto-isometric-web`

## 1. Non-negotiable architecture

1. **One mutation boundary.** All productive actions construct detached candidates, validate the complete schema, persist through `CrossDomainTransaction`, publish once, and carry bounded exact-once receipts.
2. **One interaction authority.** The highlighted adjacent cell, sealed option catalog, Phase B revalidation, and existing terminal remain authoritative. Quick actions and every new provider route through them.
3. **One simulation clock.** `DayAdvanceService` resolves closing-day growth, construction, workers, extraction, production, hauling, wellbeing, and economy before calendar advancement; dawn handles renewal and applicant lifecycle.
4. **Bounded persistence.** Schema 5 uses exact keys, explicit caps, canonical sorting, sparse generated-world deltas, and a simultaneous documented maximum below 1.5 MiB.
5. **Batched presentation.** No per-building, per-deposit, per-tree, per-crop, per-worker, or per-fish authoritative Nodes. Visible chunk records and pooled overlays only.
6. **Original art.** Every new game image, icon, structure, deposit, settler, sapling stage, and fish asset is generated with GPT Image 2, processed deterministically, cataloged, checksumed, and Web-export asserted.
7. **Input parity.** Desktop keyboard/mouse, controller, and touch expose the same semantic commands, focus order, previews, cancellation, and reasons.

## 2. Hard bounds

| Collection | Initial hard cap |
|---|---:|
| Constructed buildings | 64 |
| Cells per footprint | 16 |
| Accepted settlers | 24 |
| Housing assignments | 24 |
| Work assignments | 24 |
| Open concerns | 24 |
| Resource delta records | 256 |
| Planted trees | 512 |
| Fishing spots | 64 |
| Logistics jobs | 128 |
| Exact-once receipts | 128 |
| Recipes per building | 8 |
| Local stacks per buffer | 12 |
| Tutorial lessons | 16 |
| Maximum canonical save | <1.5 MiB |
| Ordinary 100-day save target | <256 KiB |

## 3. Transaction namespaces

`quick:*`, `construction:*`, `deposit:*`, `applicant:*`, `assignment:*`, `shift:*`, `transfer:*`, `production:*`, `wellbeing:*`, `tree:*`, `fish:*`, and existing day/machine/ecology namespaces remain independent. A duplicate operation ID returns the prior deterministic result or rejects as already applied; a conflicting payload under the same ID always rejects.

## 4. Ordered day transaction

1. Validate source revision and day token.
2. Apply closing-day effective weather to crops and trees.
3. Advance construction work.
4. Resolve staffed extraction shifts.
5. Resolve production work orders.
6. Resolve logistics transfers.
7. Resolve equitable food, shelter, rest, safety, care, and morale.
8. Resolve nonfatal injury and concern state.
9. Settle existing shipping/machines/economy.
10. Recover tools/stamina and reconcile legacy residents.
11. Advance calendar.
12. At dawn: renew eligible sources, recover injuries, expire/generate one applicant, and resolve departure notices.
13. Validate, size-preflight, persist once, publish once.

## 5. Phased execution

### P0 — Baseline, budgets, ownership, and rollback manifest

**Scope**

- Freeze current schema-4 fixtures and the 1,997-check smoke baseline.
- Record caps, byte budgets, token namespaces, operation dispatch parity, RuntimeOwnership targets, export paths, Web budgets, and rollback bundle policy.
- Add no gameplay or save shape changes.
- Generate and approve the GPT Image 2 concept target and asset manifest.

**Acceptance**

- `git diff --check`, repository-wide `gdlint`, direct import, focused baselines, full smoke, bounded boot, `verify.sh --release`, and exported-PCK boot pass.
- Native landscape/portrait baseline and the existing public Web build remain visually correct.
- Commit and push the plan/art manifest before P1.

### P1 — Schema 5 and exact-once persistence foundation

**Scope**

- Introduce envelope schema 5 with pure 4→5 migration.
- Advance farm and homestead substates to version 2 with neutral sections for construction, gathering, workforce, logistics, fishing, orchard, tutorial, receipts, and revisions.
- Add `PersistenceBudgetCatalog`, per-section bytes, size preflight, canonical sort, exact-key validators, aggregate max-envelope generator, and source/result revisions.
- Add bounded `ExactOnceReceiptLedger` and recovery for committed receipts.
- Add browser persistence capability probe and honest nonpersistent warning.

**Acceptance**

- Schemas 1/2/3/4 migrate once to byte-stable schema 5.
- Legacy expedition, farm, Lyra/Rook/Mira, requests, machines, ecology, and world mutations remain semantically identical.
- Cap+1, malformed, future, duplicate, and unknown-key records reject.
- Simultaneous documented maximum encodes below 1.5 MiB.
- Fault injection for open/write/flush/rename/backup/publish yields complete source or complete candidate after restart, never mixed state.
- Full regression, release, PCK, browser migrate-save-close-reopen, commit, and push.

### P2 — Safe Quick action

**Scope**

- Add `QuickActionPolicy` pure catalog and controller coordinator.
- Add `harvest_quick_action`: keyboard G, certified controller left trigger, and eighth touch-dock slot.
- Initial allowlist contains only uniquely enabled low-risk collect/harvest/claim actions.
- Ambiguous, stale, disabled, irreversible, costly, applicant, assignment, construction, gift, ship, sleep, or upgrade choices open the terminal.
- Reuse exact sealed option and Phase B identity/equality revalidation.

**Acceptance**

- Legacy descriptors are byte-stable and collision-free.
- One press/tap produces one mutation/save/publish; hold/re-entry cannot duplicate.
- Stale identity or changed option produces no write and opens terminal.
- Keyboard/controller/touch produce equal result IDs and canonical state.
- Full interaction, input, smoke, release, browser, commit, and push.

### P3 — Contextual tutorial (retired)

**Scope**

- Remove the contextual tutorial director, presenter, semantic event ingestion, binding formatter, modality tracker, and dedicated tests.
- Remove tutorial cards, help UI, countdown/fade behavior, touch exclusions, localized copy, and Settings training controls.
- Retain only the neutral schema-5 save slot as inert compatibility data so existing saves continue to validate.

**Acceptance**

- Gameplay enters the field with no tutorial or training UI at any viewport.
- No runtime tutorial mutation path, event consumer, preference authority, or input exclusion remains.
- Legacy schema-5 saves and old preference files continue to load safely.
- Full regression, release, browser, commit, and push.

### P4 — Construction and path-safe building shell

**Scope**

- Fix mutation-ledger placement persistence first.
- Add ledger remove/replace, stable instance IDs, receipt tokens, and building/ledger bijection.
- Add `BuildingCatalog`, footprint rotation, `PlacementValidator`, bounded `PathSafetyService`, `BuildingOccupancyIndex`, and `ConstructionService`.
- Add place, upgrade, permitted move, demolish, material reservation, construction work, and salvage.
- Add build mode with separate ghost overlay and GPT Image 2 structures.
- Protos provides a minimal build rate; unassigned settlers add bounded rate later.

**Acceptance**

- Four rotations and asymmetric footprints are canonical.
- All blockers, protected paths, corridor sealing, entrances, expansions, and demolition are tested.
- Retry does not double-spend/place/salvage.
- Walkability, target resolution, dirty cells, zero per-building Nodes, and modality parity pass.
- Full regression, release, Web, commit, and push.

### P5 — Finite and renewable deposits

**Scope**

- Add `ResourceDepositCatalog` and deterministic projected source IDs.
- Add finite salvage/mineral and managed biological renewal policies.
- Persist only sparse charge, reservation, depletion, and renewal exceptions.
- Add manual gather options and extraction-camp range previews.
- Add GPT Image 2 rich/depleted/renewing atlases.

**Acceptance**

- Same seed/chunk/day yields identical sources across native/Web/reload.
- Exactly N gathers exhaust an N-charge source.
- Replay spends one charge and credits once.
- Ten-year depletion/renewal soak remains ≤256 active deltas and bounded bytes.
- Full regression, release, browser traversal, commit, and push.

### P6 — Applicants, protected housing, and worker slots

**Scope**

- Preserve the three named specialists unchanged.
- Add finite `SettlerCatalog` with authored humans and GPT Image 2 portraits/sprite atlases.
- Add one seven-day applicant offer after safehouse + protected bed, three-day expiry, accept/decline/defer, and finite cooldowns.
- Add `HousingProtectionService` and `WorkforceService` for protected beds, one site/slot assignment, two non-overlapping shifts, preferences, and availability.
- Add applicant and roster/work-slot modal with full modality parity.

**Acceptance**

- Repeated dawn and decision tokens do not duplicate.
- No bed/power/protection/cap/slot/incompatibility rejects without mutation.
- Success creates exactly one settler and one bed/assignment record.
- All authored assets/locales validate; zero per-settler Nodes.
- Full regression, release, browser save-reopen, commit, and push.

### P7 — Exact-once staffed extraction and construction work

**Scope**

- Add `SettlerDayService` and `GatheringExtractionService`.
- Resolve sites by stable ID and slots by index using integer work units.
- Validate building, power, source, tier/range, worker, shift, safety, and local capacity.
- Atomically reserve one charge, credit camp output, advance work, and record one receipt.
- Unassigned settlers contribute bounded construction; full/unsafe/depleted state yields explicit idle reasons.
- Add batched working/carrying/resting statuses.

**Acceptance**

- Duplicate/interrupted shifts converge to one state.
- Input order permutations produce equal snapshots.
- Full buffers, no worker, unsafe site, and publish failure leave state exact.
- Dense 24-settler node/redraw checks pass.
- Full regression, release, Web sleep-reload, commit, and push.

### P8 — Warehouse hauling and production policy

**Scope**

- Add explicit building-local input/output APIs.
- Add bounded, merged, prioritized `LogisticsService` transfer jobs.
- Add warehouse hauler slots, carry/range limits, worker self-haul fallback, forced delivery, and reserve floors.
- Generalize recipe definitions to alternatives, outputs/byproducts, duration, enabled state, priority, and target.
- Adapt existing workbench/furnace through one compatibility layer.

**Acceptance**

- Transfer replay moves once; blocked capacity/reserve/publish failure changes nothing.
- Recipe alternatives, limits, priorities, local storage, distinct work-order IDs, and legacy manual claim pass.
- Ten-year maximum-jobs soak remains bounded.
- Full regression, release, Web background/save-reopen, commit, and push.

### P9 — Humane wellbeing, safety, recovery, and departure

**Scope**

- Resolve explainable shelter, food, rest, safety, medical care, voice, and belonging factors daily.
- Add bounded morale with localized reason IDs.
- Add safety stop, one open concern per active settler, deterministic nonfatal injury, later-shift suspension, clinic/rest recovery, and no reporting penalty.
- Add reasoned notice with two-day minimum remedy window and voluntary exact-once departure.

**Acceptance**

- Outcomes are order/reload deterministic and exact-once.
- No death or instant eviction path exists.
- Safety reports do not reduce morale or rewards.
- Notice/remedy/recovery/departure occur on exact days and cannot replay.
- Ten-year hardship soak, content review, visuals, regression, release, browser, commit, and push.

### P10 — Seasonal crops, saplings, and deterministic fishing

**Scope**

- Add one `SeasonalGrowthPolicy` used by preview and commit.
- Preserve six crop IDs, thresholds, atlases, and yields; add bounded affinities and dormant out-of-season policy.
- Add up to 512 planted-tree records, authored GPT Image 2 stages, collision checks, growth, harvest, and rendering.
- Add `FishCatalog`, fishing spot counters, deterministic hash-based catch resolution, rod/bait items, and pond provider.
- Add GPT Image 2 fish and item art.

**Acceptance**

- Season boundary and closing-day weather order are exact.
- Existing crops remain compatible; dormancy resumes correctly.
- Tree and fish cancel/full inventory/save failure/replay are no-write or exactly-once as appropriate.
- Native/Web catches match for equal inputs.
- 4,096 plots + 512 trees remain chunked and dirty-only.
- Full regression, release, browser fishing, commit, and push.

### P11 — Integrated certification and public release

**Scope**

- Freeze content and run fixes only.
- Generate simultaneous-max schema, representative 100-day save, and 1,000-day deterministic schedule.
- Run 120-minute native and 60-minute Chromium/Firefox soaks.
- Audit every script, catalog, locale, font, audio file, and GPT Image 2 asset in the export filter.
- Retain prior exact bundle and schema-4 backup; keep one Web origin.

**Acceptance**

- Entire migration, receipt, day fan-out, quick/tutorial, construction, deposits, workforce, logistics, wellbeing, seasons, trees, fishing, smoke, lint/import, native boot, release export, and exact PCK suites pass.
- Browser matrix covers keyboard/controller/touch, five viewports, normal/private/blocked storage, hard refresh, tab suspension, corrupt-primary backup, audio unlock, and console/network errors.
- Two native and two Web 1,000-day runs produce matching canonical hashes.
- Refresh existing `proto-isometric-web`, type/build test, restart, visually verify, save checkpoint, publish, verify public URL, archive report/bundle, tag/push exact source.

## 6. Asset production plan

All generated assets use **GPT Image 2** and the established isometric Protos Harvest style.

| Pack | Deliverables |
|---|---|
| Construction | Shelter Pod, Salvage Camp, Survey Drill, Coppice Station, Field Warehouse, Fishing Platform, Fabricator Annex, and construction stages |
| Deposits | Salvage cluster, mineral seam, biomass patch, rich/depleted/renewing variants |
| Settlers | Finite reviewed catalog; portrait plus idle/walk/work/carry/rest/concerned/recovering atlas per person |
| Logistics | Crates, hauling cart props, status icons, raw/refined resource icons |
| Orchard | Sapling, young, mature, dormant stages with one cell anchor |
| Fishing | Fish icons/portraits, rod, bait, restrained pond feedback |

Source prompts, dates, references, processing scripts, hashes, and runtime paths are recorded in provenance manifests. Generation masters remain outside the source repository; optimized runtime assets and `SOURCES.md` enter source.

## 7. Phase completion ritual

For every phase:

1. Re-read this plan and the conceptual proposal.
2. Re-fetch and integrate upstream changes before final testing.
3. Run focused tests and all affected historical suites.
4. Run direct import, bounded boot, full smoke, and log error scan.
5. Run Xvfb landscape/portrait checks with representative input.
6. Run `verify.sh --release` and exact PCK boot.
7. Update this plan with evidence and known bounds.
8. Commit and fast-forward push to `main`.
9. Do not begin the next phase while any gate is red.

## 8. Implementation status

### P0 implementation evidence

**P0 is complete.** Canonical source began at revision `0c728825c4700d76e656f1f0ed57a799b5dbda06` on synchronized `main` with no uncommitted source work. The proposal, exact phase plan, ownership boundaries, collection caps, transaction namespaces, day ordering, save budgets, rollback policy, and GPT Image 2 concept manifest are now source controlled. Five 2560×1440 GPT Image 2 concepts define the stewardship settlement, construction mode, finite-source logistics, respectful applicant/work assignment UI, and seasonal orchard/fishing targets; runtime clarifications prevent cinematic density or generated text from becoming literal implementation contracts.

The unchanged Godot 4.7.2 candidate passed the complete `verify.sh --release` gate, including direct import, repository-wide lint, audio checks, the **1,997-check** smoke suite, bounded native boot, Web export, branded loader generation, and exact exported-PCK boot with `[PCK_BOOT_PASS]` and `[PASS] Protos Harvest --release`. The export contains HTML, JavaScript, WASM, PCK, desktop/mobile loader art, icons, and worklets. P0 changes documentation only; gameplay/save compatibility therefore remains byte-identical.

### P1 implementation evidence

**P1 is complete.** The certified implementation is source commit `06036c53d326dd86ac2064ba6c71a3d88e09e6e3`. Envelope schema 5, farm/homestead substate version 2, pure schema-4 migration, neutral construction/gathering/workforce/logistics/fishing/orchard/tutorial sections, bounded exact-once receipts, canonical source/result revisions, section preflight budgets, recoverable validated temporary saves, deterministic fault injection, and honest browser-persistence capability reporting are implemented and registered in the explicit Web export. `SaveRepository` remains within the 1,000-line and 30-public-method limits at 975 lines and 17 public methods.

The focused P1 harness passed **45 checks**. It proved byte-stable schema-3/4 migration to schema 5, exact-key and cap-plus-one rejection, duplicate IDs, overlapping footprints, orphan reservations/work sites, duplicate beds, receipt duplicate/conflict/cap/canonical-order behavior, metadata-independent gameplay hashes, exact single-revision advancement, tamper rejection, and all `open`, `write`, `flush`, `rename`, `backup`, and `publish` restart outcomes. The simultaneous validator-valid maximum measured **272,582 bytes**, below the strict **1,572,864-byte** limit; the corresponding ordinary save measured **2,479 bytes**, below the 256 KiB target. All historical phase 0–6 and interaction A/B/C runners passed, and the canonical smoke gate increased from 1,997 to **2,042 checks**.

The synchronized Godot 4.7.2 candidate passed direct import, the required 120-frame bounded boot, repository-wide `gdlint`, `git diff --check`, Xvfb gameplay at 1280×720 and 720×1280 with representative `W`, `D`, and `E` input, `verify.sh --release`, and exact exported-PCK boot. Landscape and portrait SHA-256 values are `a846245e33dd820f42704e934cb2bf2c68e201e6bf98a03518cb8afb27696398` and `ca1a2bd21d7c08b48883b8ee893baa58e70c14b434c32dcf9317ea11c5b63326`. The release contains 7,853-byte HTML, 279,815-byte JavaScript, 39,514,754-byte WASM, and 66,196,288-byte PCK artifacts; every P1 runtime authority was observed in the export log.

HTTP browser verification loaded the exact release with successful HTML/JavaScript/WASM/PCK/icon/worklet requests, entered gameplay, exercised the universal terminal, and cold-reloaded with a clean WebGL runtime console. A separate Web harness using the same production persistence authorities completed the required **schema 4 seed → pure schema 5 migration → schema 5 save → close/reload → reopen** sequence. It preserved the schema-4 source until commit, wrote a 2,308-byte schema-5 envelope at result revision 1, persisted primary and backup files in IndexedDB-backed `/userfs`, and reopened the same tutorial-suppressed receipt with `[BROWSER_REOPEN_PASS]`. Because `navigator.storage.persisted()` was false, both game and harness emitted the intended `persistence_not_guaranteed` warning rather than overstating durability.

### P2 implementation evidence

**P2 is complete.** The certified implementation is source commit `7a325455979de25e9f827983113b647382776005`. `QuickActionPolicy` and `QuickActionCoordinator` now resolve a fresh target, build a fresh sealed menu, require exactly one uniquely enabled zero-cost one-cell collect/harvest/claim option, and execute the exact sealed dictionary through Phase B equality revalidation. All ambiguous, stale, disabled, costly, non-closing, applicant, assignment, construction, gift, ship, sleep, upgrade, and irreversible choices fail closed to the standard terminal. `harvest_quick_action` is bound to keyboard **G**, controller left trigger, and the eighth touch-dock slot; the pre-P2 descriptor set remains frozen at SHA-256 `c4743995be283237384034dba82290eff12e5dfe6253f9034c9430f666141905`.

Quick gameplay mutation and its schema-5 receipt now share one cross-domain save and one live publication. The receipt token binds the source result revision and canonical sealed-option digest; replay and conflict perform zero additional writes or publications. Committed repository-stamped envelopes are adopted after every transaction, including sequential farm-only actions. Publish failure compensation persists complete source gameplay on the next valid revision and synchronizes the restored farm authority, preventing both mixed state and revision reuse. The focused P2 harness passed **23 checks**, including edge-trigger/single-fire behavior, synchronous re-entry, exact option equality, modality-equivalent result IDs, touch single-fire, replay/conflict, sequential revision adoption, probe compensation, and real `SaveRepository` compensation. Interaction A/B/C, Harvest phases 3–6, P1, repository-wide lint, and direct import remained green; canonical smoke increased from 2,042 to **2,065 checks**.

Responsive certification covers 1280×720, 1024×576, 844×390, 720×1280, and 390×844 in both handedness modes. The eight-slot dock owns its touch rectangle, avoids Smash and zoom controls, and keeps **QUICK** localized in English and Simplified Chinese. Portrait zoom controls move to the free handedness-aware gutter, while command, Smash, and zoom controls hide for the terminal modal lifetime. Real Godot 4.7.2 Xvfb sessions at 844×390 and 390×844 accepted movement and native **G** input, rendered the complete dock without overlap, and opened the responsive terminal fallback without underlying action controls. Final landscape dock/fallback SHA-256 values are `facffc8aa43f70b5f18e6c49d61ddf5f7d92eb07ae14191e80773022070f1ff9` and `652a692f3d4ad42dc0cc83fa7e31d6ed78e97d9a7409f5b5cdb637558639b5f4`; portrait values are `a8ca0f4deea44ea1cd47a38f068cd5bd185a0e61335adb86e8e918e87d4810c2` and `542c34e8bb07040fd4a92ef767fba9385d86fbe9424a0d3bd2707f5fc99d310c`.

The synchronized Godot 4.7.2 candidate passed the 120-frame bounded boot, `git diff --check`, `verify.sh --release`, and exact exported-PCK boot with `[PCK_BOOT_PASS]` and `[PASS] Protos Harvest --release`. The final export contains 7,853-byte HTML, 279,815-byte JavaScript, 39,514,754-byte WASM, and 66,210,612-byte PCK artifacts, with both Quick authorities observed in the PCK export. HTTP browser verification returned successful HTML/JS/WASM/PCK/loader/icon/worklet responses, entered the homestead, opened the terminal through a browser-native **G** press, consumed a second **G** under modal ownership, and produced no script, parse, resource-load, or runtime errors. The only console warning was the expected honest `persistence_not_guaranteed` notice.

### P3 retirement evidence

The contextual tutorial was later removed from the shipping game. The retirement deletes all tutorial runtime authorities, cards, controls, bindings, localization keys, touch exclusions, semantic event consumers, preference fields, and dedicated tests. The former farm tutorial section remains only as a neutral validated schema-5 compatibility slot; no runtime path reads or mutates it. Current release evidence is recorded by the repository history and WebDev release memory rather than the obsolete tutorial certification below.

### P4 implementation evidence

**P4 is complete.** The certified implementation is source commit `959576b6ee55af777c8985b433b1bc3993829933`. Seven original construction blueprints now support canonical four-orientation footprints, bills, entrances, GPT Image 2 structures, and small/large scaffold states. The repaired workshop exposes the sealed construction planner. One pooled ghost, one pooled responsive presenter, and one modal controller provide keyboard, controller, and touch parity for site movement, rotation, blueprint cycling, commit, and cancel. Placement rejects actors, fixed blockers, crops, machines, orchard trees, existing construction, protected paths, blocked entrances, pond constraints, and bounded settlement-corridor cuts.

Construction mutations use stable building IDs, schema-5 source revisions, canonical payload digests, `construction:*` exact-once receipts, and one cross-domain candidate containing both the homestead record and world-ledger placement. Save validation enforces a strict building/world bijection, known runtime blueprints, supported levels 1–3, canonical orientation footprints, and no invisible orphan blockers. New structures block movement immediately, render as one batched record, complete after one authoritative sleep, and support permitted move, two terminal-accessible upgrades, and explicitly confirmed partial-refund demolition. Move and demolition share one dependency predicate covering local stacks, recipe policies, worker assignments, resource reservations, and logistics endpoints. Native dialog Cancel clears modal ownership; a rejected confirmation retains context for review instead of silently closing.

The focused P4 harness passed **39 checks**. It proved catalog and rotation validity, five-viewport panel bounds, GPT Image 2 alpha integrity, workshop terminal entry, actor/protected-path/overlap rejection, lower-layer actor-proof enforcement, bounded safe-site search, one bill and one receipt on placement, immediate walkability blocking, one-sleep completion, strict save rejection, exact cold reload, one render record per building, all-footprint E targeting, atomic relocation, level-2 and level-3 upgrades, dependency-consistent demolition eligibility, deterministic salvage, native Cancel recovery, retained failed-confirmation context, and five bounded lifecycle receipts. P1 remained green after strict blueprint validation; its validator-valid simultaneous maximum measured **274,873 bytes** and ordinary save **2,302 bytes**. Historical interaction A/B/C and Harvest phase gates passed, and canonical smoke completed **2,099 checks**.

Real Godot 4.7.2 Xvfb sessions with dummy audio verified the high-contrast planner at **844×390** and **390×844**, with all nine actions visible, modal HUD/radar yielding, compact touch labels, and the GPT Image 2 blueprint emblem. Separate **1024×576** proofs show the lower-center-anchored scaffold and completed Shelter Pod before and after exactly one sleep. Their SHA-256 values are `14ad1bca0183b7fd1cd623071f8efaa260d37a116ccbc48bde5cb5d6236c5990`, `94bbe419352d360d1c61d41a5a20db104528eddb869b9ae65836698c68e242bf`, `d46128883968d993d13cba84c8c7e8f35c332381b4bf8817ba15522972cd6833`, and `409ec19f075383bbf0ac1b726ad12f995f8ca916693b725719145c2bba038e2f`.

The synchronized candidate passed repository-wide lint, direct import, the 120-frame bounded title boot, `git diff --check`, `verify.sh --release`, and exact exported-PCK boot with `[PCK_BOOT_PASS]` and `[PASS] Protos Harvest --release`. The final export contains 7,853-byte HTML, 279,815-byte JavaScript, 39,514,754-byte WASM, and 68,715,572-byte PCK artifacts, with every P4 authority and selected construction asset observed in the export log. HTTP verification returned 200 for HTML/JS/WASM/PCK/loader/icon/worklets, loaded the production title and field, accepted trusted movement, recovered cleanly after one browser-tab interruption, and ended with no script, parse, resource, or runtime failure. The only console warning was the expected honest `persistence_not_guaranteed` notice.

### P5 implementation evidence

**P5 is complete.** The certified implementation is source commit `e71605ed0857685089099c1455048aaab43b5afa`. `ResourceDepositCatalog` now projects bounded SHA-256 salvage, mineral, and managed-biomass sources with stable reversible IDs, deterministic seed-sensitive density, finite or scheduled-renewal policy, source tiers, compatible extraction blueprints, and level-based ranges. Manual Gather is a sealed Phase B exact-once transaction that debits one charge and one tool/stamina cost, credits one bounded inventory reward, records one canonical receipt, and rejects stale, exhausted, reserved, incompatible-tool, or duplicate mutations without partial state. Sparse schema-5 deltas retain only nondefault charges, renewal schedule, and reservation owner; dawn compaction removes restored renewable defaults and rejects nonprojected or live-world-suppressed sources through the same authoritative world resolver used by interaction and rendering.

The focused P5 harness passed **27 checks**. It proves the frozen projection digest across native state, representative extreme seed density bounds, reversible unique IDs, strict renewable scheduling, authorized GPT Image 2 atlas hashes, world and construction blocking, truthful tool reasons, exactly-N exhaustion, stale-option rejection, same-token replay, cold-reload exhaustion, manual/building reservation ownership, and complete/compatible/tiered/in-range building authority. A deterministic **3,650-day** depletion/renewal soak remained within the **256-delta** cap and the **90,000-byte** gathering budget. The independent audit findings were resolved before certification: malformed zero-charge renewable records now fail closed, reservation authority cannot be forged by unknown/incomplete/wrong-tier/wrong-blueprint/out-of-range buildings, dawn compaction uses live-world blocker precedence, asset authorization checks exact SHA-256 values, and density tests cover a representative signed/extreme seed corpus. Automated staffed reservation and extraction scheduling remains intentionally owned by P7.

Three optimized transparent GPT Image 2 atlases render rich, depleted, exhausted, and renewing phases through the existing visible-chunk batch path with zero per-source Nodes. Godot 4.7.2 Xvfb with dummy audio verified **1024×576** rich/depleted transitions, an **844×390** exhausted state, and **390×844** portrait touch geometry. Their SHA-256 values are `7a51975d01480b011eb25b8fa37b098defd87373084498aace293590102fc2c5`, `6ff2cce96e1bb6b869d4944a4d1c03ea6f519b9cf784778dacf7681ea8cc72e7`, `ca9d2c857d481d9aa0291c3bdb3d013a4c4fee3b51a582bf4e710453e9b462a2`, and `031a7f4c157558aca14db5db1580cf53a83ec5326063fec82f26fc78630533f1`.

P1–P4, interaction Phase B, historical cross-domain Phase Four, repository-wide lint, direct import, and the 120-frame bounded title boot remained green. The final `verify.sh --release` gate completed **2,107 smoke checks**, measured a validator-valid maximum envelope at **273,476 bytes** and ordinary envelope at **2,479 bytes**, exported all P5 authorities and atlases, booted the exact PCK, and ended with `[PCK_BOOT_PASS]` and `[PASS] Protos Harvest --release`. The Web bundle contains 7,853-byte HTML, 279,815-byte JavaScript, 39,514,754-byte WASM, and 69,282,588-byte PCK artifacts. HTTP browser verification returned 200 for HTML/JS/WASM/PCK/loader/icon/worklets, loaded the title and field, accepted trusted movement and terminal input, restored controls on Escape, and produced no script, parse, resource, network, or runtime exception; the only console warning was the expected honest `persistence_not_guaranteed` notice.

### P6 implementation evidence

**P6 is complete.** The certified implementation is source commit `cb2eb97957bcfddcf52acfe4053cd6c9b3148bfd`, fast-forwarded onto concurrent upstream `main` revision `184aa620e01577fb8dc0e38f9a78cfd69f9a0e01` before final certification. Eight finite authored applicants now have stable IDs, biographies, traits, needs, preferences, and GPT Image 2 portrait/static-world resources. One offer is evaluated idempotently every seventh dawn only after the powered safehouse and an available protected bed; it expires on the third following dawn, never queues missed unsafe cycles, and supports exact-once invite, decline, and finite one-day defer decisions. Lyra, Rook, and Mira remain unchanged under their original named-resident authority.

`HousingProtectionService` derives deterministic safehouse and completed Shelter Pod beds without mutable capacity counters. `WorkforceService` enforces one protected bed, one active settler to one compatible completed site/slot, and one of two non-overlapping shifts; recovering status, duplicate occupancy, incomplete/incompatible sites, absent housing, stale revisions, and invalid slots reject without mutation. Applicant and assignment operations use `applicant:*`, `assignment:*`, and `shift:*` receipts through `CrossDomainTransaction`. A pre-P6 compatibility adapter verifies the original raw schema-5 result hash before adding the neutral applicant lifecycle, then rebases the normalized hash so already-committed P1–P5 saves remain valid without weakening tamper rejection. An independent audit found and drove closure of three hazards before certification: raw-hash migration order, stale-offer identity, and stale-roster optimistic concurrency.

The focused P6 harness passed **32 checks**, including eight-person catalog determinism, exact asset hashes/dimensions/alpha, additive hashed-save migration, cadence/expiry/defer/decline, no-queue behavior, stale-offer rejection, exact-once invite/replay/conflict, protected-bed assignment, node-free rendering, stale workforce revision rejection, recovering-worker rejection, duplicate shift occupancy, exact-once shift changes, schema validity, and cold reload. All **17** bounded historical/interaction/settlement runners passed. The simultaneous validator-valid schema maximum measured **273,501 bytes** against the 1,572,864-byte limit; the ordinary envelope measured **2,453 bytes**. Repository-wide `gdlint`, direct import, `git diff --check`, source budgets, the 120-frame boot, and the integrated **2,119-check** smoke suite passed.

Sixteen optimized transparent GPT Image 2 PNGs total **2,063,099 bytes**: eight 320×400 portraits and eight 256×384 lower-center-anchored static world sprites with committed import sidecars, provenance, and exact SHA-256 authorization. Node-free batched records preserve the three named resident records. Real Godot 4.7.2 Xvfb sessions with dummy audio and representative input verified a **1280×720** applicant card, **1280×720** roster/work-slot state, **844×390** scroll-mediated roster, **430×860** portrait applicant state, and **1024×576** admitted-settler world composition. Their SHA-256 values are `1168f34920fa5cb37c04341c349a89f52215c6241b19bd28e99040cf08012b19`, `93c9ce3b62eedcad3210167c07a499746ff1d459154918da7b4e281d244d320b`, `4cf2d08a6275306a9ccf4ba48d1d9a42490041df8226ff8d726b111a2520ea0`, `26c29a5612b0410cb1b4b8e233b4c6fb3cacd7b858eedf5161db1f18639126a7`, and `f87768256708cad52950c4c32e53f67178b9b60c577fff9dd7a26bfa97a836d4`.

The final upstream-integrated `verify.sh --release` exported 7,853-byte HTML, 279,815-byte JavaScript, 39,514,754-byte WASM, and 70,883,936-byte PCK artifacts, observed every P6 authority in the explicit export, booted the exact PCK, and ended with `[PCK_BOOT_PASS]` and `[PASS] Protos Harvest --release`. HTTP browser verification loaded the final simplified title and field, accepted trusted Enter/D/E input, opened the sealed terminal, hard-reloaded to the persisted homestead record, reopened `/userfs` from IndexedDB, and produced no script, parse, resource, network, or runtime exception. The only warning was the intended `persistence_not_guaranteed` notice because durable storage was not granted. **P7 staffed extraction and construction work is the next sequential gate.**

### P7 implementation evidence

**P7 is complete.** The certified implementation is source commit `b042c0f7bef234e9937bbb25cf818cd30768053c`, fast-forwarded onto concurrent upstream `main` revision `0c465b2c789c9a872b369da3066097361ab6e288` before its feature push. A second runtime wave through `6887d3a` and final test-only interaction certification through `b6c5367` were then integrated before the evidence gate. `SettlerDayService`, `GatheringExtractionService`, and `BuildingLocalStorageService` now resolve closing-day staffed work through the one authoritative day candidate. Unassigned active settlers contribute bounded integer construction units while Protos always contributes the baseline unit. Assigned extraction workers resolve by stable site ID, slot, and one of two shifts; complete/powered building authority, compatible slot, safety, source kind, tier, range, reservation, remaining charge, and local capacity all fail closed before mutation.

A productive shift reserves one compatible deterministic source to its extraction site, consumes exactly one charge, credits the authored yield into the building's bounded local output, and records one `shift:day.*` receipt. Duplicate/replayed day tokens converge to the prior candidate. Finite and managed-renewable P5 source semantics remain authoritative, manual gathering observes building reservations, and local output remains a hard move/demolition dependency until P8 logistics transfers it. Compatible reserved, exhausted, and absent sources now retain distinct `source_reserved`, `source_exhausted`, and `no_compatible_source` reasons; full output, unsafe site, recovering settler, non-extraction slot, and no worker also remain explicit and non-mutating.

P7 persists a bounded canonical `shift_reports` list so productive and idle outcomes survive cold reload and drive truthful **working**, **output ready**, **resting**, **recovering**, and exact idle-reason presentation. Reports are linked to current assignments/sites, cleared on assignment changes or demolition, and exposed in the native roster/work-site UI. The compatibility adapter verifies genuine P6-era raw schema-5 hashes before adding the neutral report field and rebasing the normalized hash; tampered legacy envelopes still reject. Persisted building-local stacks now reject unknown ItemCatalog IDs and per-item stack-limit overflow at cold-load validation. No per-settler or per-building authority Nodes were added.

The independent first audit found three medium risks—transient idle presentation, collapsed reserved/exhausted source reasons, and permissive cold-load local stacks—and all were corrected. A second independent audit reported **no high- or medium-severity findings remaining** after reviewing report bounds, migration, cleanup, exact-once retention, cross-section links, capacity, and the simultaneous maximum envelope.

The focused P7 runner passed **22 checks** covering bounded construction contribution, exact-once productive shifts, persisted reports, source reservation and one-charge depletion, local output, unsafe/recovering/full/no-worker/non-extraction/reserved/exhausted/absent-source idle behavior, schema migration and tamper rejection, malformed local-stack rejection, batched presentation, a **180-day** staffed soak with exactly **64 retained shift receipts**, and cold-reload receipt/source/output/replay identity. The final upstream-integrated bounded matrix passed **19/19 suites**, including all interaction phases, P0–P6 settlement regressions, and the new interaction-inspection suite. `./verify.sh --release` passed **2,145 smoke checks**, direct import, repository-wide lint, audio-loop gates, bounded boot, export, and exact exported-PCK boot. The schema-5 simultaneous maximum remained validator-valid at **294,279 bytes** against the 1.5 MiB hard bound; the ordinary envelope measured **2,472 bytes**.

Real Godot/Xvfb evidence covers **1280×720 desktop roster**, **844×390 short-landscape roster**, **430×860 portrait roster**, and a **1024×576 staffed-world** frame. The final front-edge work anchor keeps the authored GPT Image 2 settler sprite fully visible in front of the extraction building. A real Web cold-load frame additionally shows the completed Salvage Camp, Field Warehouse, and admitted settlers restored from the P7 save. Visual SHA-256 values are recorded in the external P7 evidence manifest.

The final Web bundle contains **7,853-byte HTML**, **279,815-byte JavaScript**, **39,514,754-byte WASM**, and **71,606,748-byte PCK** artifacts. Their SHA-256 values are `e3627152ae14d2b8a9c76aac988687a7cfa0e5bf773b5aca07cf63745ca7b797`, `33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba`, `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`, and `e503c5769990d31efa51f0c0916063e559193275b0b5b61f0d38e4033fa38f28`, respectively. HTTP browser verification loaded the final upstream title and field, accepted trusted Enter/D/E input, opened the sealed terminal, returned correct JS/WASM/PCK MIME types, and produced no script, parse, resource, network, or WebGL failure; the only warning was the intended `persistence_not_guaranteed` notice.

For direct Web save-reload evidence, an exact real P7 day-transaction envelope was loaded from IndexedDB: **8,332 bytes**, revision 10, day 4, two settlers, one assignment, one productive report, one local-output stack, reservation, and receipt. The Web runtime rendered its completed buildings and settlers, hard-reloaded twice, and preserved byte-identical SHA-256 `6d2a5bfb68de23c4b1a16c703105bd944b56d7f5175b518b1040af83b2321709` without duplicate shift application. **P8 warehouse hauling and production policy is the next sequential gate.**

### P8 implementation evidence

**P8 is complete.** The certified source is split across fast-forward commits `7ad0dc8` (**warehouse logistics and production implementation**) and `80a6a84` (**approved ten-year soak certification**), both pushed to canonical `origin/main`. The implementation adds explicit local input/output storage, deterministic merged transfer jobs, warehouse reserve floors, hauler and bounded self-haul capacity, exact-once forced delivery, recipe alternatives and byproducts, staffed automated production orders, shared stock targets, and one compatibility adapter preserving legacy manual machine debit and claim behavior.

Persistence remains schema 5 and cold-loads pre-P8 records through additive normalization. Construction records now carry bounded input stacks and active orders; logistics carries canonical jobs and reserve rules. Cross-section links reject unknown items, non-fabricator production state, incompatible or incomplete transfer endpoints, impossible workforce slots, and every report—including no-worker sentinels—on incomplete sites. The ordinary candidate is **2,491 bytes** and the simultaneous documented maximum is **274,001 bytes**, below the canonical **1,572,864-byte** limit.

The final bounded regression matrix passes **20/20 runners**: interaction inspection **19**, interaction A/B/C **14/23/21**, legacy harvest phases **83/32/19/24/21/15**, P5 authorities/presentation **19/13**, settlement P1–P8 **45/23/43/39/27/32/22/22**. The expanded P8 suite proves replay-safe forced delivery, reserve immutability, deterministic job ordering, successful-capacity accounting, no-warehouse output preservation, alternative inputs and byproducts, shared in-flight targets, namespace saturation recovery, strict migration/link rejection, responsive native UI, and cold reload. Its logistics/production soak now runs **3,650 consecutive days** and stays schema-valid with transfer and production receipts bounded to their shared quotas.

The independent audit found one high-severity receipt-saturation risk and five medium issues. All were corrected: shared deterministic namespace quotas reserve record capacity while preserving the newly committed token; forced-delivery IDs use fixed-width revisions; shared targets count every in-flight order; failed transfers spend no haul capacity; persisted assignments/reports/jobs require complete compatible sites; and compact UI uses localized short tabs, one-column grids, an explicit empty queue, and physical viewport-safe bounds. A re-audit found only an incomplete-site sentinel-report gap; that gap was then fixed and regression-covered. No high- or medium-severity finding remains.

Real Godot/Xvfb evidence covers **1280×720 desktop**, **844×390 short-landscape**, and **390×844 portrait** Logistics & Production states with dummy audio and representative keyboard focus input. The final captures show explicit queue state, delivery, reserve, fabricator, recipe, enabled, priority, target, and policy controls. The portrait panel and complete tab row remain inside the physical screen without horizontal scrolling; constrained layouts use vertical scrolling and ≥44-pixel touch targets. Capture SHA-256 values are `07975b4b43e5859ffc9f1eb370dc600d09e4e963a9c24a3d966fe3f3045dcd0f`, `21c9f2d1d81471ead92a6cd939a4bf205d2c043f5b2ea3b0407a8c7decf9d78c`, and `312689b95953115f4ab6c7a1e8a9960c1ea8e57f89243e26cbf4706b964c8d82`, respectively.

`./verify.sh --release` passes with **2,152 smoke checks**, bounded boot, explicit Web export, and `[PCK_BOOT_PASS]`. The bundle contains **7,853-byte HTML**, **279,815-byte JavaScript**, **39,514,754-byte WASM**, and **71,710,436-byte PCK** artifacts. Their SHA-256 values are `d61a3f61ab54f657e9376b6af8c987cb430d026b76b8b68a3ae96a5f7bafc7f9`, `33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba`, `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`, and `4144f6c594ee63ea7fd98b30c8280f3f8abab9ea21658f50e79982acf7824606`, respectively.

HTTP browser verification loaded the final upstream-integrated title and field, accepted trusted Enter/D/E input, opened the sealed interaction terminal, and loaded JavaScript/WASM/PCK without script, parse, resource, rendering, or WebAssembly errors. The only console warning was the intended browser durability notice. **P9 humane wellbeing, safety, recovery, and voluntary departure is the next sequential gate.**

### P9 implementation evidence

**P9 is complete.** Fast-forward commit `3dc9bef` implements humane daily wellbeing, exact safety stops, deterministic nonfatal injury/recovery, one bounded explainable concern per active settler, a two-day remedy window, voluntary departure, departed-person applicant exclusion, and a native wrapping roster detail pane. The commit is pushed to canonical `origin/main` without rewriting shared history. Lyra, Rook, and Mira remain unchanged.

Schema 5 now persists bounded morale, localized reason IDs, injury/recovery day, notice day/deadline, remedy state, and disjoint departure history. Genuine pre-P9 hashed envelopes migrate through raw-hash verification followed by additive normalization; tampered saves still reject. Departure removes housing, assignment, report, and concern links atomically while preserving a bounded identity history. The ordinary candidate is **2,517 bytes** and the simultaneous documented maximum is **280,506 bytes**, below the canonical **1,572,864-byte** limit.

The final bounded matrix passes **21/21 runners**: interaction inspection **19**, interaction A/B/C **14/23/21**, legacy harvest phases **83/32/19/24/21/15**, P5 authorities/presentation **19/13**, and settlement P1–P9 **45/23/43/39/27/32/22/22/22**. Repository smoke passes **2,158/2,158**. The P9 suite proves daily exact-once replay/conflict, equitable all-or-none rations, bounded morale, exact two-day notice/remedy/departure timing, no death or instant eviction path, deterministic injury, clinic-shortened recovery, exact-day work eligibility, authoritative `site_unsafe` handling, safety-stop reward/morale neutrality, departure cleanup and exclusion, ten-year hardship stability, save/hash validity, and cold reload.

Independent audit initially found three medium issues: a safety reason mismatch, recovery reconciliation after workforce consumption, and clipped single-line wellbeing details. All were fixed. A final targeted re-audit confirmed full closure and no remaining high- or medium-severity finding. Recovery now reconciles before construction/extraction, and the UI test awaits real frames across **390×844 portrait** and **844×390 short landscape** in **en** and **zh-CN**, asserting complete panel/detail bounds, wrapped lines, ≥44-pixel touch targets, and visible localized morale, concern, remedy, and deadline text.

Real Godot/Xvfb captures with dummy audio cover **1280×720 desktop**, **844×390 short landscape**, and **390×844 portrait** wellbeing rosters. The selectable summary remains compact while the dedicated wrapping pane exposes the full ration concern, concrete remedy, day-102 deadline, notice state, protected bed, assignment, and rest state. Capture SHA-256 values are `8263527258730b6868077ab0c7a5afb4a452186e48981ed559232aee53e6562d`, `49caf596ba51c59d9922ac5179b028d62872a262a2c9e4c83dd56b3470124223`, and `a06e043a600d398e993b78db67d3df164293926c8ae49449db8951e9cc8831b6`, respectively.

`./verify.sh --release` passes Godot **4.7.2 stable**, explicit Web export, bounded boot, **2,158 smoke checks**, and `[PCK_BOOT_PASS]`. The bundle contains **7,853-byte HTML**, **279,815-byte JavaScript**, **39,514,754-byte WASM**, and **71,729,256-byte PCK** artifacts. Their SHA-256 values are `cf54cfe5db6ff7fb07923b989de1724fcf2feac7579442341fc3ce0d79950b59`, `33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba`, `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`, and `886960bef08f3d942f134426bbc498b4c109d2d74510db15105dd0d8e04ec6e1`, respectively.

HTTP browser verification loaded the exact title and field, accepted trusted **Enter/D/E** input, opened the sealed terrain terminal, and loaded JavaScript/WASM/PCK without script, parse, resource, rendering, or WebAssembly errors. Hard reload returned cleanly to the title; the only runtime warning remained the intended browser durability capability notice. **P10 seasonal crops, saplings, and deterministic fishing is the next sequential gate.**


### P10 implementation evidence

**P10 is complete.** Source commit `f5f97b081720e2bdffbddd50f08a3f968dc65ba2` implements seasonal crops, authored orchards, and deterministic fishing and is fast-forward pushed to canonical `origin/main`. The candidate was integrated through upstream revision `8d16e3b59f8ae7b9131600fa8dbf0b45702cb0ca`, preserving the upstream contextual-tutorial removal and hidden sanctuary markers before final certification.

`CropCatalog` preserves all six crop IDs, thresholds, atlases, and yields while freezing varied seasonal affinities. Closing-day growth uses one deterministic favored/dormant policy: out-of-season crops remain planted and resume when a favored season returns. `OrchardCatalog`, `OrchardService`, and centralized `FarmOccupancyService` add two authored species, collision-safe world-valid planting, protected home service lanes, bounded maturity/regrowth, exact-once harvest and humane immature-sapling lifting, node-free chunked atlas presentation, and the approved **512 planted-tree** persistence bound. Plots, machines, fixed farm services, facilities, home, construction, and existing trees reject overlap before stamina or inventory mutation; construction and movement use the same occupancy truth.

`FishingCatalog` freezes three live biome pools and four catches. Woodland pond, oasis mire pool, and frozen rime melt project through authoritative world features and block movement. `FishingService` enforces rod and optional bait inventory, deterministic hash-weighted catches, exact bait effects, finite per-spot counters, partial dawn renewal, full-inventory rollback, native/Web-identical inputs, and exact-once replay/conflict/stale-revision behavior. Tree planting, harvest, lifting, and fishing remain intentional terminal actions and never enter Safe Quick.

Ten GPT Image 2 runtime PNGs total **1,077,156 bytes**: two four-stage orchard atlases, four fish icons, two sapling icons, one fishing rod, and one luminous bait icon. Deterministic chroma cleanup, lower-center anchoring, source/runtime SHA-256 values, and generation provenance are committed in `assets/settlement/P10_SOURCES.md`; generation masters remain external. Real Godot 4.7.2 Xvfb with dummy audio and representative input verifies a **1280×720** orchard world, **1280×720** tree menu, **844×390** fishing menu, and **390×844** fishing menu. Final visual SHA-256 values are `958fb93b37540781243ca771876dd096ae75f3e77e98114e0f9777f545778495`, `a635e9ac461e6d1a11ec6791b3ee19d23f1999a9cebb9f2949f634939ba4ff24`, `7e37615d4f71cd84aa6c09b5c6225f8e5a6c1c9caa6ed5fb70ec92ddcfd47057`, and `4dd4f3e3fce6b1de01d75c50cafba0039c7b59ca8ce866cb85c44dac57d1fff1`.

The independent audit found no critical defect but identified gaps in live-pool reachability, orchard capacity semantics, reverse-direction occupancy, exact stamina previews, tree receipt coverage, fishing rollback, public presentation evidence, locale reasons, and responsive terminal bounds. Every item was corrected. A final targeted re-audit returned **PASS** with no unresolved high- or medium-severity finding. The focused P10 runner passes **27/27 checks**, including all three live pools, exact seasonal boundaries, 512-tree capacity, native batched rendering, replay/conflict/stale-state behavior for every mutation, bait weighting, missing-bait and full-inventory no-write paths, cold reload, and a ten-year seasonal soak.

The final upstream-integrated bounded matrix passes **21/21 runners**. The simultaneous validator-valid schema-5 maximum contains all **4,096 plots** and **512 trees**, measures **270,530 bytes** against the **1,572,864-byte** hard limit, and leaves the ordinary candidate at **2,517 bytes**. `./verify.sh --release` passes direct import, repository lint, audio loops, bounded boot, **2,141 smoke checks**, explicit Web export, exact PCK boot, `[PCK_BOOT_PASS]`, and `[PASS] Protos Harvest --release`.

The exact final Web bundle contains **7,853-byte HTML**, **279,815-byte JavaScript**, **39,514,754-byte WASM**, and **72,599,048-byte PCK** artifacts. Their SHA-256 values are `2c9eb5c779f5f09ef15db0ddbc44929213f42519c04abdd88655776be1ce1517`, `33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba`, `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`, and `50980d3ab7f23101c63ba17bb9efde6ad7c072668d89b68ac91ef4418bc521fe`, respectively. HTTP browser verification loaded the exact title and field, accepted trusted keyboard input, opened the native terminal, and loaded JS/WASM/PCK without script, parse, resource, WebGL, or rendering errors. The only warning was the sandbox's explicit `storage_blocked` capability notice; native cold reload and deterministic focused tests therefore carry persistence and fishing transaction certification without overstating browser durability. **P11 integrated certification and public release is the next sequential gate.**
