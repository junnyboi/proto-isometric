# Protos Harvest
## Stewardship Settlement Redesign Proposal

**Author:** Manus AI  
**Canonical repository:** https://github.com/junnyboi/proto-isometric  
**Engine target:** Godot 4.7.2 stable  
**Design status:** Approved for implementation by user request

## 1. Vision

**Protos Harvest** becomes a post-apocalyptic farming, construction, logistics, and monster-combat simulator in which **Protos remains the immediate, capable player character** while a small human community gradually contributes bounded automation. The player still drives, farms, fights, explores, and makes every consequential decision. Settlers do not replace play; they convert hard-won safety, housing, infrastructure, and trust into a modest settlement that can keep functioning while Protos ventures into hostile biomes.

The resource economy takes inspiration from the strongest abstract patterns in *Against the Storm*: nearby deposits have finite charges, gathering requires compatible staffed work buildings, outputs enter local storage before reaching a warehouse, recipes expose priorities and limits, and hauling capacity becomes a meaningful bottleneck. The official reference describes worker slots, blueprint construction, resource delivery, camps, building ranges, internal storage, recipe priorities, and production limits.[1] Deposits have finite charges, compatible camp requirements, and can disappear when exhausted.[2] Recipes can accept alternative ingredients and form visible production chains.[3] Eremite Games' logistics redesign also demonstrates why haulers work best as warehouse assignments and why lower inventory limits should reserve stock from production.[4]

These principles will be **adapted rather than copied**. Protos Harvest keeps its own fiction, terminology, assets, values, interface, combat, biomes, and persistent characters.

> **Core promise:** protect a clearing, cultivate living systems, build a settlement, give humans a safe place to choose meaningful work, and use the resulting resilience to challenge a hostile world.

## 2. Design pillars

| Pillar | Player-facing consequence |
|---|---|
| **Immediate robot agency** | Manual farming, gathering, combat, building, and interaction remain fast and rewarding. Automation is optional and never globally passive. |
| **Finite local ecology** | Salvage, ore, biomass, trees, and fishing spots have understandable capacity, renewal, or exhaustion rather than infinite invisible faucets. |
| **Legible logistics** | Work buildings have worker slots, range, local buffers, priorities, limits, and explicit idle reasons. Goods move through visible, bounded steps. |
| **Humane settlement stewardship** | Applicants request protection; the player may invite, decline, or defer. Accepted settlers need protected beds, rest, safety, food, care, and voice. |
| **Deterministic simulation** | Day advancement, arrivals, catches, growth, production, injury, and departures use integer rules, canonical ordering, stable IDs, and exact-once receipts. |
| **One interaction language** | Contextual E/A/touch menus remain authoritative. Quick actions accelerate safe repetition; consequential choices remain explicit terminal actions. |
| **Batched presentation** | Buildings, deposits, trees, crops, and people are authoritative records rendered through visible chunk batches and pooled overlays, not one Node per entity. |
| **Persistent compatibility** | Existing farms, expeditions, Lyra, Rook, Mira, livestock, machines, combat, habitats, and schema migrations remain valid. |

## 3. The new daily loop

A typical day begins with a concise settlement briefing: season, weather, available applicants, idle work buildings, full local storage, shortages, and safety concerns. The player may farm manually, fish, plant saplings, place blueprints, assign settlers, adjust a warehouse reserve, or leave the clearing for combat and salvage.

During the day, **Quick Action** accelerates repetitive low-risk chores. Facing a highlighted target and pressing **G**, controller left trigger, or the touch Quick button executes only one freshly validated, uniquely eligible safe action. Ambiguous, expensive, irreversible, stale, or choice-bearing actions open the full interaction terminal instead. Quick is a shortcut into the same authority, never a second mutation path.

At sleep, one deterministic transaction resolves closing-day crop and sapling growth, construction work, assigned shifts, extraction, production, hauling, wellbeing, machines, and economy settlement. The calendar then advances; dawn handles renewal, applicant expiry or generation, recovery, and departure notices. If persistence fails, none of these systems partially advances.

## 4. Contextual tutorial without rectangle warfare

The existing timer-driven onboarding becomes an **event-driven field guide**. It teaches one relevant action at a time:

1. Move Protos.
2. Face an actionable highlighted cell.
3. Open the interaction terminal.
4. Navigate only when multiple rows exist.
5. Confirm one safe action.
6. Use Quick on an eligible target.
7. Open construction mode when the first blueprint unlocks.
8. Assign a settler only after the first applicant is admitted.

Prompts advance only after semantic success. Time, duplicate events, failed transactions, stale targets, or disabled rows never complete a lesson. Skip hides guidance without granting completion; Resume restores the current lesson; Reset Training clears the bounded progress mask.

## 5. Seasonal farming, orchard, and fishing

The existing four seasons become mechanically meaningful without destroying old farms. Each crop receives bounded seasonal and weather affinity. In-season crops may gain an integer growth bonus. Out-of-season crops become **dormant rather than dead**, preserving player investment and resuming when the season returns.

Saplings use a separate sparse planted-tree overlay. Players may plant only on valid empty cells that do not overlap paths, buildings, farm plots, pond, wild trees, or protected landmarks. Trees advance at sleep through authored stages and may become seasonally dormant. Mature harvesting uses exact-once harvest sequences and the existing inventory overflow rules.

Fishing begins at the fixed woodland pond. Availability is derived from world seed, spot, absolute day, cast sequence, season, effective weather, and a coarse time band. There is no frame-perfect timing meter and no wall-clock randomness. Cast, confirm, and cancel work identically on keyboard, controller, and touch; successful catches atomically spend bait/stamina and credit inventory once.

## 6. Construction and protected settlement growth

Construction mode is a temporary presentation state: choose a blueprint, move a ghost, rotate, inspect footprint and entrance, confirm, or cancel. Previewing does not spend resources or write saves.

A committed building has one stable instance ID, catalog blueprint, anchor, orientation, level, construction state, delivered bill, worker slots, local storage, and policy records. The construction transaction reserves materials, places exact footprint occupancy, preserves required paths, and persists once. Unassigned settlers may add bounded construction work, but Protos always supplies a minimal baseline so the player is never blocked by population.

Initial buildable structures:

| Structure | Purpose |
|---|---|
| **Shelter Pod** | Protected human beds and power requirement |
| **Salvage Camp** | Extracts nearby wreckage and scrap deposits |
| **Survey Drill** | Extracts compatible mineral seams |
| **Coppice Station** | Manages renewable biomass and planted trees |
| **Field Warehouse** | Central logistics, reserve rules, and hauler slots |
| **Fishing Platform** | Expands pond yields and worker fishing |
| **Fabricator Annex** | Bounded production recipes and alternatives |

Placement rejects blockers, protected paths, occupied plots, fixed facilities, player/resident cells, inaccessible entrances, and corridor sealing. Demolition is explicit and exact-once; protected legacy facilities cannot be demolished.

## 7. Resource deposits and gathering

Untouched deposits are deterministic world projections. Saves persist only sparse exceptions: remaining charges, renewal day, reservations, and depletion. This prevents the save from growing with explored world area.

| Source class | Behavior |
|---|---|
| **Finite salvage** | Wreck clusters and machine debris exhaust permanently |
| **Finite mineral** | Ore and crystal seams exhaust permanently |
| **Managed biological** | Coppice, reeds, and selected biomass renew on deterministic days |
| **Seasonal aquatic** | Pond availability changes with season/weather and may be manually or professionally fished |
| **Manual wilderness rewards** | Hostile habitats and boss rewards remain player-driven and never become passive jobs |

Work buildings have range and compatible source tiers. A staffed shift reserves one charge, produces into local output storage, and records one receipt. Replaying the shift cannot consume or credit again.

## 8. Human settlers

Lyra, Rook, and Mira remain the named specialist residents with their existing schedules, relationships, gifts, requests, and facilities. Dynamic humans use a **separate bounded settler model**.

Every seven days—after the safehouse and a protected bed exist—one deterministic applicant may request shelter. The applicant card shows identity, traits, needs, work preferences, housing impact, and offer expiry. The player may invite, decline, or defer. Missed cycles do not create a queue.

Accepted settlers are not inventory. They receive one protected bed, may be assigned to one building and one humane shift plan, can stop unsafe work without retaliation, may recover from deterministic nonfatal injury, and may voluntarily depart after an explainable notice period if persistent needs remain unmet. Traits modify preferences and proficiency, never human worth.

Initial population cap is **24 settlers**, with at most one open concern per active settler and two non-overlapping shifts. Presentation uses authored GPT Image 2 portraits and isometric animation atlases for a finite catalog rather than procedural palette swaps.

## 9. Work, storage, production, and hauling

Extraction outputs remain in the source building until hauled. Warehouses may assign settlers as haulers; workers retain a limited self-haul fallback to avoid deadlocks. Transfer jobs are merged and bounded, then ordered by explicit priority, age, source, destination, item, and stable job ID.

Production buildings expose enabled recipes, ingredient alternatives, priority, target count, and local input/output buffers. Warehouse reserve rules protect a lower stock threshold from production while preserving explicitly documented exceptions for construction and player actions. Existing workbench and furnace behavior is migrated through one compatibility adapter to prevent double debit or credit.

## 10. Pressure without cruelty

Settlement pressure comes from clear, remediable conditions: unpowered shelter, food shortages, insufficient rest, unsafe work, untreated injury, unresolved concerns, and lack of belonging. Each morale change exposes a stable reason. Injury stops later shifts and never kills a settler. Reporting unsafe work creates no morale or reward penalty, aligning the feature with worker-participation principles.[5] Work remains bounded rather than glorifying extreme hours, consistent with public-health evidence linking very long workweeks to elevated risk.[6]

Low morale begins a notice, not instant deletion. The player receives at least two days and concrete remedies. Recovery may cancel the notice. Otherwise the settler departs voluntarily, freeing the bed and assignment exactly once.

## 11. Persistence, performance, and release constraints

All new state enters one additive **schema 5** migration with neutral defaults. The maximum simultaneous documented state must encode below **1.5 MiB**, leaving margin under the repository's two-megabyte hard limit. Ordinary 100-day play targets less than 256 KiB. No collection may grow from play time alone.

The simulation uses integer work units and project-owned stable hashes. Authoritative arrays are sorted before selection. Day advancement is the sole clock. No gameplay authority depends on `_process(delta)`, Dictionary iteration order, engine RNG implementation details, wall-clock time, or rendered visibility.

Every phase must pass focused tests, legacy suites, direct import, bounded boot, Xvfb visual checks, Web export, exported-PCK boot, browser network/runtime scans, and a push to `main` before the next phase.

## 12. Success criteria

The redesign is successful when:

- repetitive chores are faster but cannot bypass validation;
- the tutorial teaches behavior only when relevant;
- seasons, fishing, and saplings enrich farming without invalidating old saves;
- construction is spatial, path-safe, reversible, and exact-once;
- deposits are finite or intentionally renewable and do not inflate saves;
- human applicants remain authored individuals with agency and protection requirements;
- staffed buildings produce only through bounded shifts, local buffers, and visible logistics;
- manual play remains immediately valuable;
- maximum-state and long-horizon simulations remain deterministic and bounded;
- the published Web build loads, saves, reloads, and runs without console or pack errors.

## References

[1]: https://wiki.hoodedhorse.com/Against_the_Storm/Buildings "Against the Storm Official Wiki — Buildings"
[2]: https://wiki.hoodedhorse.com/Against_the_Storm/Resources "Against the Storm Official Wiki — Resources"
[3]: https://wiki.hoodedhorse.com/Against_the_Storm/Recipes "Against the Storm Official Wiki — Recipes"
[4]: https://eremitegames.com/logistics-and-balance-update/ "Eremite Games — Logistics and Balance Update"
[5]: https://www.osha.gov/safety-management/worker-participation "OSHA — Worker Participation"
[6]: https://www.who.int/news/item/17-05-2021-long-working-hours-increasing-deaths-from-heart-disease-and-stroke-who-ilo "WHO/ILO — Long Working Hours and Health"
