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

### P3 — Contextual tutorial

**Scope**

- Replace timer authority with `ContextTutorialState`, `ContextTutorialDirector`, `InputModalityTracker`, binding formatter, and one pooled native presenter.
- Lessons: move, target, open terminal, navigate when needed, confirm safe action, use Quick, enter build mode, assign first worker.
- Persist only version, completion bitmask, and suppression in the bounded farm tutorial section; preferences retain only one-time legacy migration input and remain under their existing budget.
- Add Skip, Resume, Reset Training, More Help, localization, accessibility names, UI scale, safe area, handedness, and focus yielding.

**Acceptance**

- Identical progression at 30/60/144 FPS, pause, idle, reload, and shuffled duplicate events.
- Failed/stale/disabled actions never advance.
- Preferences migrate and stay ≤4 KiB.
- English/zh-CN parity and five-viewport visual checks pass.
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

### P3 implementation evidence

**P3 is complete.** The certified implementation is source commit `d0ea12a28aa4c2e16d3090d3c31728c0c3aaeab7`. The timer-driven onboarding authority was removed and replaced by `ContextTutorialState`, `ContextTutorialDirector`, validated semantic tutorial events, `InputModalityTracker`, localized binding formatting, and one pooled native presenter. The eight lessons cover committed movement, valid target acquisition, terminal opening, enabled-row navigation when applicable, successful safe confirmation, committed Quick mutation, build mode, and first worker assignment. Construction and worker lessons remain dormant until their capabilities are published by their owning future phases.

Tutorial progression is a bounded farm-owned schema-5 mutation containing only version, completion mask, and suppression. A structural pre-stamp validator now permits repeated schema-5 cross-domain candidates while `PersistenceStateHash.apply_next` still requires exact committed revision equality and produces the next source/result hash pair. Legacy `onboarding_seen` migrates once to reversible suppression without granting false lesson mastery, then clears from active preference authority. Skip, Resume, Reset Training, and More Help have distinct semantics; the More Help panel traps focus, while the compact prompt yields to the terminal and settings. Keyboard/mouse, controller, and touch bindings are localized with exact English/Simplified Chinese key parity.

The focused P3 harness passed **39 checks**. It proved identical event convergence at 30/60/144 FPS and under shuffled duplicates, rejected timer/unknown state, cap-plus-one state, zero-distance movement, invalid targets, failed confirmation, failed Quick, missing receipts, disabled navigation, and dormant future capabilities, and demonstrated one write per completed lesson. Live fresh-farm tests progressed through committed movement, target acquisition, terminal opening, disabled-row rejection, safe confirmation, farm-envelope persistence, More Help modal ownership, input restoration, radar yielding, and exact cold-reload restoration. P1, P2, interaction A/B/C, Harvest phases 4–6, repository-wide lint, and direct import remained green; canonical smoke increased from 2,065 to **2,093 checks**.

Responsive certification covers 1280×720, 1024×576, 844×390, 720×1280, and 390×844 across UI scales 0.85/1.0/1.25 and both handedness modes. Real Godot 4.7.2 Xvfb sessions with dummy audio verified a compact short-landscape prompt, portrait prompt with radar yielding, desktop large-scale More Help, and left-handed portrait large-scale More Help. No helper rectangles were added. Prompt/help SHA-256 values are `56f8f15c13c785f7c0ef9d2d9e5167553c75b751a60a588e1a1d49f311e86d20`, `4c695700491dc377bd31112bd13601160b5887af76ac80a29724bdfcb1d67ec0`, `405e496629ffaaf5c3737c2c1adb0c910a385aa141e38e8a50bf4281a00244e8`, and `90504baf8e2eaae5c22a4231d22039596520c09cdf9410460382f7b0aa48e388`.

The synchronized Godot 4.7.2 candidate passed direct import, repository-wide `gdlint`, a 120-frame bounded boot, `git diff --check`, `verify.sh --release`, and exact exported-PCK boot with `[PCK_BOOT_PASS]` and `[PASS] Protos Harvest --release`. The final export contains 7,853-byte HTML, 279,815-byte JavaScript, 39,514,754-byte WASM, and 66,246,304-byte PCK artifacts, with all six P3 runtime authorities observed in the export log. HTTP browser verification returned successful HTML/JS/WASM/PCK/loader/icon/worklet responses, honored returning-player tutorial suppression, accepted browser-native movement and terminal input, and produced no script, parse, resource-load, or runtime errors. The only console warning was the expected honest `persistence_not_guaranteed` notice.
