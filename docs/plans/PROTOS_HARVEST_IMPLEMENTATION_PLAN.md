# Protos Harvest
## Complete Gameplay Redesign Proposal and Implementation Plan

**Author:** Manus AI  
**Date:** 25 August 2026  
**Canonical repository:** [`junnyboi/proto-isometric`](https://github.com/junnyboi/proto-isometric)  
**Planning baseline:** `98663d7b2e762ec9984d72ff0c6594b960ba6d84`  
**Engine target:** Godot 4.7.2 stable, GL Compatibility, desktop and no-threads Web export

## 1. Executive recommendation

**Protos Harvest** should become a persistent farming and settlement RPG about a caretaker robot rebuilding a living refuge in a damaged world. The primary structure should no longer be a short relay expedition governed by escalating Alert. Instead, the game should be organized around durable days: tend crops, restore the clearing, build relationships, process resources, and decide whether a purposeful journey into a hostile biome is worth the remaining daylight and risk.

This is a pivot, not a demolition. The repository already contains a mature deterministic isometric world, streamed terrain, four harsh biomes, destructible resources, ancient safehouse ruins, responsive controls, monsters, peaceful fauna, bosses, weather, accessibility systems, localization, transactional persistence, and a strong verification pipeline.[1] [2] [3] The redesign should retain those expensive foundations and change the **reason they exist**. Biomes cease being scenery for aimless traversal and become supply regions that unlock irrigation, tools, facilities, crops, recipes, and settlement restoration. Monsters become territorial wilderness challenges rather than timer-driven interruptions. Ruins become repairable infrastructure. The Walker becomes a caretaker rather than a combat runner with a gardening side hustle.

The genre target is deliberately hybrid. The official *Story of Seasons* framing emphasizes farm investment, community restoration, produce processing, and a recurring market destination.[11] The official *Rune Factory 4 Special* description combines farming with fishing, crafting, village relationships, monsters, and adventure.[12] **Protos Harvest should adopt that complementary structure without copying either game's tone or scope**: the farm is the emotional and economic center, while the wilderness gives its growth meaning.

> **Player promise:** You are a resilient caretaker robot rebuilding a warm, productive sanctuary in a hostile world. Every morning offers understandable choices, every crop and repaired ruin visibly improves home, and every dangerous journey is optional, signposted, and tied to a concrete homestead goal.

## 2. Why the current loop feels boring

The existing game is mechanically capable but structurally repetitive. Movement, biome transitions, combat, hazards, relay objectives, rewards, and extraction all function, yet most activity resolves into the same decision: continue moving until the next encounter or objective. Alert escalation creates pressure, but it does not create attachment. Scrap and Worm Cores change combat effectiveness, but they rarely change the world in a way the player can see and care about.

The redesign addresses three missing forms of meaning.

| Missing value | Current symptom | Protos Harvest response |
|---|---|---|
| **Place attachment** | Safehouses are useful terminals, not a home. | The woodland clearing becomes a persistent, authored-feeling sanctuary whose fields, paths, facilities, residents, and lighting visibly evolve. |
| **Rhythmic contrast** | Traversal and danger dominate almost every minute. | Calm mornings, chores, planning, social time, expeditions, and night settlement form a varied daily cadence. |
| **Purposeful accumulation** | Resources mostly repair or improve the current run. | Produce, materials, monster drops, and ruin technology unlock permanent tools, buildings, crops, recipes, and biome restoration. |

The central design test is therefore not “is there more content?” It is:

> **Does every expedition improve the home, and does every improvement create a new reason to care about tomorrow?**

## 3. Product identity and design pillars

### 3.1 Distinctive fantasy

The player is **Protos**, a broad industrial caretaker robot awakened in a sheltered woodland clearing. The world beyond is ecologically unstable: deserts suffer glasswinds and buried predators; wetlands conceal corrosive blooms; frozen regions fracture under ice shear; volcanic fields erupt through ancient infrastructure. Protos is not trying to conquer the wilderness. It is learning how to cultivate pockets of life within it.

This preserves the existing robot silhouette, ancient-machine ruins, teal/amber visual grammar, mechanical audio, and hostile biome identities while giving them a warmer purpose. “Machine learns stewardship” is a stronger proprietary identity than “another pastoral farmer” or “another short combat run.”

### 3.2 Core pillars

| Pillar | Design commitment |
|---|---|
| **Care made legible** | Adjacent-cell actions, readable soil states, predictable growth, clear forecasts, gentle early failure, and a quiet HUD make routine work satisfying rather than obscure. |
| **A sanctuary worth returning to** | Home is always safe. Crops, paths, restored facilities, residents, lighting, music, and visible activity make progress spatial and emotional. |
| **Risk by choice, reward with purpose** | Crossing a gate is a deliberate decision. Each dangerous region offers materials or discoveries that unlock a specific farm or settlement capability. |
| **One continuous world** | The farm is a sparse persistent overlay on the existing streamed isometric field, not a disconnected minigame or a second renderer. |
| **Durable, atomic progress** | Sleep resolves the day through one validated transaction; important actions save immediately and roll back completely if persistence fails. |
| **Scope before breadth** | Prove one season, three residents, three facilities, one expedition arc, and one boss-gated farm upgrade before animals, romance, festivals, or all-season content. |

## 4. The new opening: woodland sanctuary

### 4.1 Starting composition

A new game begins at the existing deployment vicinity, centered on cell `(8,10)`, but the area is no longer behaviorally desert. A pure `WoodlandClearing` classifier should reserve a bounded region before harsh-biome surface conversion. The opening composition should include:

| Element | Initial specification |
|---|---|
| **Inner clearing** | Roughly nine cells in radius; walkable woodland grass with no hostile spawns or damaging hazards. |
| **Farm apron** | At least one contiguous 6×6 tillable area, free of trees, rocks, ruins, hazards, relays, mud, ice, and lava. |
| **Home safehouse** | Fixed to the ancient safehouse visual near `(8,4)`, rather than selected from a random ruin family. |
| **Water** | A visible pond, cistern, or restored well point reachable without leaving safety. |
| **Tree belt** | A three- to four-cell ring of deterministic broadleaf and conifer trees with readable one-cell trunks. |
| **Gates** | Four two-cell-wide exits with short safety buffers, each visually hinting at the world beyond. |
| **Starter infrastructure** | Shipping/storage terminal, bed/charging station, broken workbench, and a small seed cache. |

The existing world streamer uses eight-cell chunks, a radius-two 5×5 loaded ring, a 29×29 visible window, and deterministic coordinate-derived content.[3] The clearing must therefore be an ordered generation override, not a separate tutorial map. The player sees the actual streamed world from the first frame.

### 4.2 Safety contract

The entire inner clearing is safe, not merely a collection of overlapping neon circles. One central query—`WorldSafety.is_home_safe(position)`—must be consumed by encounter spawning, creature pursuit, projectiles, deep-biome events, weather damage, and lava contact. A monster may be seen or heard beyond the tree belt, but no ordinary system may violate the promise of home.

Remote ruins retain the existing luminous sanctuary ring only after repair or activation. An unrepaired ruin is a landmark, not free immunity. This gives ruin restoration mechanical value while keeping the home visually calmer.

### 4.3 World continuity

The existing desert, wetland, frozen, and volcanic regions remain. Golden coordinates outside the reserved opening area must retain their current terrain and movement behavior. For the first release, the world should remain the current streamed **145×145 bounded field**, not be marketed as truly infinite. Expanding that boundary would affect generation, save validation, objectives, testing, and edge streaming, and is not required to prove the farming loop.[3]

## 5. Primary gameplay loop

### 5.1 Daily cadence

| Phase | Player activity | Design purpose |
|---|---|---|
| **Wake** | Review date, weather, one-day forecast, mail, requests, machine completions, and yesterday's shipping result. | Begin with understandable choices rather than urgency. |
| **Tend** | Harvest, till, plant, water, forage, feed, and start processing machines. | Deliver tactile repetition with visible progress. |
| **Connect** | Visit residents, trade, fulfill requests, repair a facility, organize storage, or improve paths. | Make the clearing socially and spatially alive. |
| **Choose the afternoon** | Continue farming, fish, craft, decorate, or cross a gate for an expedition. | Preserve player agency; combat is never mandatory every day. |
| **Explore with intent** | Gather biome materials, stabilize a hazard, repair a ruin, befriend wildlife, or enter a lair. | Make risk voluntary and goal-directed. |
| **Return and reinvest** | Deposit materials, craft an upgrade, ship produce, prepare seeds, cook, or socialize. | Convert wilderness effort into home improvement. |
| **Sleep and commit** | Resolve shipping, rain, crop growth, construction, machines, weather, restoration, and autosave. | Provide closure, anticipation, and persistence trust. |

### 5.2 Time fairness

Time should pause during dialogue, inventory, shops, construction, sleep summary, settings, and loading. No offline elapsed-time simulation should occur; browser throttling and mobile interruptions would otherwise punish the player arbitrarily. Day length should be configurable within a bounded range, with a default target of 14–16 real minutes. Exhaustion stops productive tool use but never prevents walking home or opening menus.

Missing one watering day should **pause growth** during the vertical slice rather than kill a crop. Crop death, quality variance, drought, and complex seasonal penalties can be introduced only after players trust the baseline system. This world is harsh enough without turnips developing a personal vendetta.

## 6. Farming and homestead systems

### 6.1 Farm plots and crops

Farm state is a sparse overlay keyed by global cell coordinate. Base terrain remains deterministic. A plot record owns only authored state: tilled status, last-watered day, crop ID, planted day, growth points, stage, fertilizer, regrowth count, and health/dormancy.

The initial 14-day season should contain six crops:

| Crop role | Purpose |
|---|---|
| **Fast staple** | Reaches harvest quickly and proves the loop during the first few days. |
| **Regrowing bean** | Introduces repeat yield and planning. |
| **Hardy root** | Tolerates missed watering and demonstrates crop traits. |
| **Rain-loving crop** | Rewards reading the forecast. |
| **Forage-derived herb/flower** | Connects exploration and seed discovery. |
| **Desert-affinity premium crop** | Requires a wilderness material or restored well, proving the farm–expedition dependency. |

Growth occurs once per committed dawn token. Rain waters eligible plots before growth. Reloading cannot reroll weather, apply growth twice, or duplicate a harvest.

### 6.2 Tools and interaction

The existing movement, facing, camera, and Walker animation foundations remain.[4] Passive Impact charge and universal contact-smashing do not. Farming needs deliberate target semantics.

The command vocabulary becomes:

- **Move**
- **Context Action**: talk, inspect, pick up, harvest, open, repair, pet
- **Use Equipped Tool**: hoe, watering tool, axe, hammer/pick, scythe, fishing tool, weapon
- **Previous/Next Tool**
- **Inventory / Hotbar**
- **Journal / Map**
- **Run**
- **Cancel / Pause**
- **Camera Zoom**

A visible adjacent-cell reticle shows the authoritative target. Invalid actions consume no stamina, item, or time. Context and Tool actions share the same validated command methods across keyboard, controller, and touch. Friendly fire is disabled by default; crops, NPCs, machines, structures, and friendly animals are excluded from combat and broad tool masks.

The existing Walker attack contact frame can temporarily drive tool actions, but tool overlays and dedicated chore animation must become a vertical-slice art dependency. Reusing a combat smash for watering would make agriculture look like an unresolved labor dispute.

### 6.3 Inventory, shipping, crafting, and upgrades

Scrap remains a workshop material, and Worm Cores remain valid legacy/rare components. They cease to be the universal economy. Stable item definitions should cover seeds, produce, wood, stone, ores, monster materials, food, crafted parts, tools, and currency.

Home storage is authoritative for baseline crafting convenience, while physical chests provide capacity upgrades and organization. Shipping is staged during the day and settled at sleep. Recipes consume ingredients atomically and may require station tags such as workbench, kitchen, furnace, or greenhouse.

Durable upgrade families include:

| Upgrade family | Early examples |
|---|---|
| **Tools** | Wider watering pattern, harder material breaking, lower stamina cost, faster charged action. |
| **Robot** | Chassis capacity, biome resistance, inventory slots, efficient run energy. |
| **Home** | Storage, workshop, clinic/kitchen, seed greenhouse, power capacity. |
| **Land** | Irrigation radius, soil depth, greenhouse heat, biome cultivation plots. |
| **Processing** | Furnace, dehydrator, mill, composter, elemental stabilizer. |

Existing module identities can inspire durable attachments, but persisted IDs must retain their old meanings for legacy saves. New farming upgrades receive new namespaced IDs.

## 7. Settlement, ruins, and residents

The five existing ancient ruin families should become a reusable settlement kit.[8] The home safehouse is fixed; three nearby ruins become the first repairable facilities:

| Resident | Facility | Gameplay function | Relationship scope |
|---|---|---|---|
| **Agronomist / seed merchant** | Greenhouse or seed archive | Seeds, crop knowledge, soil tests, forecast interpretation | One request chain and one personal scene in the vertical slice |
| **Mechanic / tool upgrader** | Workshop | Tools, robot upgrades, construction, remote ruin power | One request chain and one personal scene |
| **Medic / cook** | Clinic-kitchen | Recovery, cooking, buffs, food requests | One request chain and one personal scene |

Residents need stable IDs, short deterministic schedules, reachable fallback locations, localized dialogue conditions, shops, requests, and relationship milestones. Romance, marriage, children, large festivals, and a broad cast are explicitly deferred. Those systems are content multipliers disguised as checkboxes.

Restoration should be visible: broken lighting becomes warm, stalls and work areas appear, residents move through the clearing, music gains layers, and paths connect facilities. The player should identify progress in a screenshot without reading a stat panel.

## 8. Wilderness redesign

### 8.1 Ecology instead of pressure scheduling

The existing encounter director escalates relay-driven pressure and can spawn threats around the player. That model must not govern a farming day. Replace it with deterministic habitat anchors based on biome, distance from home, time, season, weather, lair state, player noise, and story permits.

Creatures become place-based:

- Territorial monsters patrol, notice, warn, chase, leash, recover, and return.
- Tiny mobs inhabit visible nests and may become crop/resource pests later.
- Peaceful herds flee, feed, bond, and yield renewable materials rather than functioning as one-hit scrap containers.
- Bosses exist in authored lairs and never appear beside the player because a timer became enthusiastic.

The existing telegraph, attack geometry, hit feedback, audio, VFX, and boss mechanics are valuable and should remain.[9] Combat is optional support content. Common wilderness materials must also be obtainable, more slowly, through gathering, trade, traps, restoration, or husbandry; otherwise combat quietly becomes mandatory.

### 8.2 Hazards as opportunities

Existing quicksand, bog gas, ice shear, magma vents, storms, and surface effects remain, but each dangerous condition needs three layers of counterplay:

1. **Forecast or environmental tell**
2. **Moment-to-moment telegraph**
3. **Preparation or mitigation**

Successful stabilization should expose value. Quicksand may reveal clay or ore. Bog gas may become an alchemical ingredient. Ice shear may open crystal seams. Magma vents may power heat crops or advanced processing. Damage-only randomness is rejected.

### 8.3 Boss-gated farm capabilities

The vertical slice uses **Ironjaw** as an authored desert guardian. It occupies a visible lair near a sealed water-table ruin. First victory grants a unique Burrow Core that unlocks a desert well or deep-tilling system at home. Leaving mid-fight is safe. First-clear state persists, and rematches cannot duplicate the progression reward.

Kilnheart becomes a later volcanic milestone whose Crucible unlocks high-temperature processing and protected volcanic cultivation. Boss rewards therefore change the farm, not merely damage numbers.

## 9. Keep, adapt, replace

| Decision | Systems and assets |
|---|---|
| **Keep** | 90×45 isometric projection; chunk streaming and culling; deterministic coordinate salts; terrain seams; four harsh biomes; movement surfaces; five ruin sprites; Walker locomotion; monsters, fauna, bosses, hazards, telegraphs, audio, VFX; responsive camera; touch layout; localization; accessibility; bounded audio/VFX; transactional save and migration tests; verification and Web export.[2] [3] [4] [5] [8] [9] |
| **Adapt** | Starter biome into woodland reserve; outposts into home/repairable facilities; scrap/cores into named materials; run pickups into item pickups; Impact targeting into typed ToolTargets; encounter director into ecology; hazards into forecastable opportunities; peaceful herds into bonding; boss rewards into farm unlocks; HUD/title/onboarding into farming semantics. |
| **Replace as the primary loop** | Relay capture, Alert I–III, mandatory extraction, modifier draft, short-run settlement, random nearby spawns, universal combat smash, always-on desert atmosphere, random starting ruin, and combat-first title art/copy. |
| **Preserve for compatibility or optional content** | Existing active runs, schema-1/2/3 save meanings, relay fields, module IDs, modifier IDs, run settlement, and old resource arrays. These remain importable and testable until explicitly retired through a documented migration. |
| **Do not do** | Do not encode crops as rocks; do not serialize generated terrain; do not create one Node per crop; do not rewrite the renderer as TileMap during the pivot; do not add animals, romance, festivals, all seasons, and all biomes before the vertical slice proves the daily loop. |

## 10. Target technical architecture

The current `isometric_map.gd` runtime composes most field systems.[4] It should remain a composition adapter, not become the authority for farming, calendar, inventory, ecology, and settlement. New services should be typed `RefCounted`, `Resource`, or local `Node` children with explicit ownership.

| Authority | Responsibility | Likely files |
|---|---|---|
| **World generation** | Base terrain, woodland reserve, generated trees/resources, biome queries, walkability | `infinite_world.gd`, new `woodland_clearing.gd` |
| **World mutation ledger** | Sparse cleared/placed object deltas, stable entity footprints, chunk indexes | new `world_mutation_ledger.gd` |
| **Farm state** | Plots, crops, watering, fertilizer, growth, harvest, farm claims | new `farm_state.gd`, `farm_plot_state.gd` |
| **Calendar/weather** | Year, season, day, time, forecast, day tokens, sleep transition | new `calendar_state.gd`, `weather_service.gd`, `day_advance_service.gd` |
| **Inventory/economy** | Item stacks, money, shipping, containers, recipes, transaction rollback | new `inventory_state.gd`, `inventory_service.gd`, `economy_service.gd` |
| **Home/settlement** | Facilities, residents, schedules, requests, ruin states, construction | new `homestead_state.gd`, `resident_service.gd`, `ruin_registry.gd` |
| **Ecology** | Habitat anchors, populations, dispositions, leashes, respawn, boss state | adapted `encounter_director.gd`; new ecology resources/services |
| **Tools/interactions** | Context scoring, target masks, stamina costs, tool effects, command intents | new `interaction_resolver.gd`, `tool_service.gd`; adapted `impact_targeting.gd` |
| **Persistence** | Schema validation, migration, candidate envelope, atomic commit and recovery | existing `save_repository.gd`, `save_migrator.gd`, `world_state_store.gd`[5] |
| **Presentation** | Visible-cell drawing, dirty invalidation, HUD snapshots, audio/VFX adapters | adapted `world_objects.gd`, `terrain_renderer.gd`, `field_ui_state.gd` |

### 10.1 Persistence model

Advance additively to **schema 4**. The existing `world`, `active_run`, and `profile` sections retain schema-3 semantics. Add a versioned `farm` domain containing:

- calendar and deterministic weather state;
- sparse plot and crop records;
- inventories, money, shipping queue, and containers;
- placed entities, machines, and queues;
- facility, home, ruin, and resident state;
- tool and durable upgrade state;
- ecology deltas and boss first-clear state;
- immutable migration and day-settlement tokens.

Generated terrain, tree placement, ruin kind, and untouched resources remain coordinate-derived. Only player-authored deltas are serialized. Records are canonicalized by chunk, cell, and stable entity ID. Every collection has coordinate, count, byte-size, duplicate, overlap, and unknown-ID validation.

Sleep uses two phases. First, `DayAdvanceService` builds and validates a detached next-day candidate in a fixed order: weather and rain, crops, machines, construction, ecology respawn, shipping, calendar, recovery, and morning events. Second, `SaveRepository` commits the entire envelope atomically. Presentation updates only after acknowledgement. Repeated callbacks carrying the same day token are ignored.

## 11. Minimum lovable vertical slice

The vertical slice is deliberately larger than a technology demo and smaller than a life-simulator franchise.

| Dimension | Committed scope |
|---|---|
| **World** | Finished woodland clearing, safehouse, pond/well, shipping/storage, 6×6 farm apron, tree belt, four gates, continuous streamed harsh world. |
| **Time** | One 14-day season, configurable day length, deterministic weather, sleep settlement, no offline progress. |
| **Crops** | Six crops with readable stages; no random quality; missed watering pauses growth. |
| **People** | Three residents, three repaired facilities, one request chain and one relationship beat each. |
| **Tools** | Hoe, watering tool, axe, pick/hammer, harvest/context, separate weapon mode. |
| **Economy** | Produce and requests provide money; wood, stone, and scrap build; one desert material enables a meaningful upgrade. |
| **Wilderness** | One desert expedition route, territorial fauna, one quicksand resource opportunity, one repairable remote ruin, and Ironjaw's lair. |
| **Progression** | Burrow Core unlocks a well/deep-tilling affordance; at least one tool and one facility upgrade. |
| **Presentation** | Final woodland, soil, crop, tool, facility, title, and clearing audio identity; English and Simplified Chinese parity. |
| **Platforms** | Keyboard/mouse, controller-ready command layer, touch; native and no-threads Web. |

### 11.1 Proof-of-fun session

Within ten simulated minutes and without entering combat, a fresh player can clear three cells, till, plant, water, sleep, observe growth, harvest, ship, buy more seed, and choose one workshop upgrade. The game is not considered pivoted until this loop is understandable and pleasant.

## 12. Detailed phased implementation plan

### Phase 0 — Baseline, identity seams, and compatibility

| ID | Work package | Key work | Exit condition |
|---|---|---|---|
| `PH-00` | Freeze release baseline | Pin Godot 4.7.2 binary/templates; run `./verify.sh --release`; record revision and bundle evidence.[10] | Unchanged native, headless, test, PCK, and Web behavior is reproducible. |
| `PH-01` | Declare ownership | Add farming, calendar, inventory, economy, home, and ecology domains to runtime ownership/IDs. | Tests reject cross-domain mutation and recycled legacy IDs. |
| `PH-02` | Schema-4 skeleton | Add neutral farm section, validators, v3→v4 migration, fixtures, and canonical ordering. | All schema-1/2/3 fixtures retain asserted semantics; fresh schema 4 round-trips. |
| `PH-03` | Dual-mode smoke | Add fresh-farm and legacy-expedition boot modes before removing old assertions. | Current active runs remain resumable and new saves can enter the clearing path. |

### Phase 1 — Safe woodland clearing

| ID | Work package | Key work | Exit condition |
|---|---|---|---|
| `PH-04` | Pure clearing classifier | Implement center, inner safety, apron, tree belt, gates, protected paths, and home cell. | 1,000 seeds preserve clearing invariants and external biome golden cells. |
| `PH-05` | Generation precedence | Apply base terrain → biome → clearing → protected paths/apron → obstacles → mutations → structures. | No gate or farm path can be blocked after all overrides. |
| `PH-06` | Woodland rendering | Add 512×512 grass/soil textures, two 256×256 leafy tree variants, stump reuse, seams, provenance, and catalog validation. | Correct 2:1 anchors, stable variants, no desert haze, and readable terrain transitions. |
| `PH-07` | Safety authority | Route all spawns, pursuit, projectiles, hazards, weather damage, and lava contact through central safety. | Seven-day soak records zero threat or damage within the buffered clearing. |
| `PH-08` | Home and ruin states | Fix the starting safehouse; add home/discovered/repaired/powered ruin states. | Home works at start; inactive remote ruins grant neither services nor immunity. |

### Phase 2 — Interaction and rendering seam

| ID | Work package | Key work | Exit condition |
|---|---|---|---|
| `PH-09` | Shared command layer | Add Move, Context, Tool, cycle, inventory, journal/map, run, cancel, zoom, remapping. | Equivalent intents on keyboard, controller, and touch. |
| `PH-10` | Target resolver | Add visible adjacent-cell reticle, typed target masks, priority, and quiet rejection reasons. | All eight facings target exactly one intended cell; invalid actions cost nothing. |
| `PH-11` | Tool/combat separation | Preserve combat attack while adding tool-action contact frames and friendly-fire policy. | Tools never damage crops, residents, machines, or friendly fauna. |
| `PH-12` | Farm render adapter | Draw soil, crops, fences, trees, and structures from visible chunk indexes with dirty-cell invalidation. | No per-frame full-world scan, no per-crop Node, and no idle redraw. |
| `PH-13` | Tall-object depth | Add diagonal depth buckets, one-cell trunks, and optional occlusion assistance. | Trees, Walker, crops, residents, and ruins sort correctly in all approach directions. |

### Phase 3 — Day-one farm proof

| ID | Work package | Key work | Exit condition |
|---|---|---|---|
| `PH-14` | Item and inventory core | Stable item definitions, robot inventory, home storage, stack/cap rules, transfers, overflow handling. | Every transfer conserves totals and rolls back on failed persistence. |
| `PH-15` | Plot and crop core | Tilling, watering, planting, stages, harvest, six data-driven definitions, deterministic yield. | Growth survives streaming and save/load; harvest credits exactly once. |
| `PH-16` | Tools and stamina | Hoe, watering tool, axe, pick, harvest/context, costs, hold-repeat assist. | Running out stops productive action but never traps the player. |
| `PH-17` | Calendar and forecast | Year/season/day/time, pause rules, current weather, next-day forecast. | Identical seed/day inputs reproduce identical forecasts. |
| `PH-18` | Day transaction | Candidate simulation, rain watering, crop growth, shipping, recovery, day token, atomic commit. | Forced interruption cannot double-advance any day result. |
| `PH-19` | Shipping and money | Shipping bin, preview, daily settlement, seed purchase, one workshop upgrade. | Complete ten-minute first-day loop passes in automated and human smoke tests. |

### Phase 4 — Authoritative persistence and economy

| ID | Work package | Key work | Exit condition |
|---|---|---|---|
| `PH-20` | Mutation ledger | Chunk-indexed cleared/placed objects, stable IDs, footprints, tree deltas, compatibility adapters. | Legacy rock/scrap arrays remain exact; new entities reject overlap and duplication. |
| `PH-21` | Cross-domain transactions | One candidate envelope for harvest, placement, transfer, crafting, sleep, return, and upgrade. | Any failed write restores every authority to its exact pre-action snapshot. |
| `PH-22` | Crafting and machines | Recipes, station tags, workbench, furnace, durations, start/complete/claim. | Ingredients and outputs are consumed/produced once across reload. |
| `PH-23` | Durable upgrades | Tool, robot, storage, irrigation, safehouse, and machine upgrade definitions. | Capabilities and costs validate; old module IDs remain compatible. |
| `PH-24` | Save bounds and soak | Hard caps, canonical sorting, save-size budget, 10-year deterministic simulation. | Validation stays within budget and saves remain below configured limits. |

### Phase 5 — Lovable homestead

| ID | Work package | Key work | Exit condition |
|---|---|---|---|
| `PH-25` | Facility restoration | Adapt three ruin families into greenhouse/seed shop, workshop, and clinic/kitchen. | Restoration persists and visibly changes services and presentation. |
| `PH-26` | Residents and schedules | Three residents, stable schedules, fallback locations, shops, requests, dialogue conditions. | No resident disappears or duplicates across construction, weather, sleep, or reload. |
| `PH-27` | Farm HUD and menus | Date, time, forecast, stamina, money, tool, item count, prompt, quest pin, inventory, shops. | Desktop, portrait, landscape, 75–150% UI, EN/zh-CN layouts pass. |
| `PH-28` | Onboarding and accessibility | First-week lessons, target snap, hold-to-tool, long-day mode, text options, combat/hazard assists. | New players complete the core loop without external instruction. |
| `PH-29` | Brand and audio | Protos Harvest title, desktop/mobile art, clearing day/night/rain music, chore SFX, new copy and markers. | Blind presentation tests identify a farming/settlement game rather than an expedition game. |

### Phase 6 — Wilderness bridge

| ID | Work package | Key work | Exit condition |
|---|---|---|---|
| `PH-30` | Ecology director | Deterministic habitats, populations, dispositions, leashes, schedules, depletion, respawn. | No timer-centered ambushes; identical state reproduces populations after streaming/reload. |
| `PH-31` | Creature conversion | Territorial large monsters, nest-based tiny mobs, friendly herd bonding and renewable yields. | Wild fauna cannot be accidentally killed by ordinary tools; trust persists. |
| `PH-32` | Loot-to-farm graph | Named loot tables and recipes connecting each material tier to a farm capability. | Routine combat cannot out-earn same-tier farming; every rare drop has a concrete use. |
| `PH-33` | Hazard opportunities | Forecasts, mitigation, stabilization, and resource outcomes for four deep-biome events. | Every event has forecast, telegraph, preparation, bounded damage, and reward. |
| `PH-34` | Desert arc and Ironjaw | Authored lair, quest gate, safe exit, persistent first clear, Burrow Core, home well/deep tilling. | First clear cannot duplicate; the reward visibly changes farming. |
| `PH-35` | Expedition return | Atomic deposit, optional loss policy only for active excursions, remote ruin activation, home re-entry. | Farm inventory is never subjected to legacy run-loss rules. |

### Phase 7 — Certification and expansion gate

| ID | Work package | Key work | Exit condition |
|---|---|---|---|
| `PH-36` | Performance certification | Worst-case mature farm, weather, residents, creatures, 30-day mixed soak. | Existing chunk, visible-cell, audio, particle, memory, and Web budgets remain bounded. |
| `PH-37` | Save and migration certification | Fresh, schema-1/2/3, backup recovery, interruption, future/malformed, multi-slot tests. | Zero partial restore, duplication, orphaning, or silent overwrite. |
| `PH-38` | Export certification | Explicit export filters, catalog-to-PCK comparison, native/Xvfb/browser screenshots, runtime logs. | HTML, JS, WASM, and PCK are nonempty; exact pack passes boot and gameplay smoke.[10] |
| `PH-39` | Localization/accessibility certification | Full EN/zh-CN parity, focus, safe areas, scaling, reduced motion/flash, audio, remapping. | No missing keys, clipped actions, unreachable controls, or color-only farm states. |
| `PH-40` | Expansion decision | Review retention, economy, comprehension, performance, and production capacity. | Animals, festivals, romance, later seasons, Kilnheart, and all-biome cultivation require an explicit green light. |

## 13. Quality gates and success metrics

| Area | Target |
|---|---|
| **Onboarding comprehension** | At least 85% of first-time testers complete till → plant → water → sleep → harvest → ship without external help. Median first planted crop ≤5 minutes; first full day loop ≤15 minutes. |
| **Home trust** | Seven-day automated soak records zero hostile spawns, projectiles, damaging hazards, lava ticks, or pursuit damage inside safety. At least 90% of testers identify gates as the risk boundary. |
| **Loop pull** | At least 70% voluntarily start day 3; 50% complete the 14-day slice; 60% of completers perform both a homestead upgrade and the optional expedition. |
| **Choice balance** | At least 30% of play days contain no combat. Routine same-tier wilderness combat value per hour does not exceed farming. |
| **Persistence integrity** | Zero duplicate harvest, shipping, boss, pickup, crafting, or upgrade rewards under forced interruptions. All old fixtures preserve meaning. |
| **Determinism** | Generation order, chunk unload/reload, restart, and save/load reproduce clearing, trees, crops, ecology anchors, and forecasts. |
| **Performance** | Preserve the existing 25 loaded chunks, ≤1,600 active cells, and ≤841 visible cells under normal configuration; no unbounded nodes or dictionaries.[3] |
| **UX parity** | Core intents work on keyboard/mouse, controller, and touch; modal opening always cancels held world input. |
| **Presentation identity** | In blind screenshot/video tests, at least 80% describe the home as a farming/settlement game rather than an expedition action game. |
| **Release closure** | Clean Godot 4.7.2 import, lint, all suites, bounded boot, exact exported-PCK boot, no-threads Web runtime, and complete asset provenance. |

## 14. Principal risks and mitigations

| Risk | Consequence | Mitigation |
|---|---|---|
| **Save-schema blast radius** | Old progress rejected or rewards duplicated. | Add schema 4 rather than broadening strict schema-3 dictionaries; preserve legacy sections and immutable migration tokens; validate detached candidates. |
| **Authority sprawl** | Calendar, farm, inventory, world, and run systems mutate each other inconsistently. | Define explicit owners, typed transactions, immutable projections, and one disk boundary. |
| **Safety leakage** | A forgotten threat path violates the home promise. | One central query and boundary-cell tests for every spawner, pursuit system, projectile, hazard, weather, and contact-damage source. |
| **Rendering cost** | Dense crops and tree crowns break Web performance or depth order. | Chunk-index sparse records, visible-only batches, dirty invalidation, no per-crop Nodes, depth buckets, and retained budgets. |
| **Interaction ambiguity** | Tool actions damage crops/fauna or feel like combat. | Separate Context, Tool, and Weapon commands before adding farm content; typed masks and friendly-fire rules. |
| **Identity gap** | The pivot feels like Walker's Wake with a farm menu. | Treat woodland, crops, tool overlays, title art, clearing music, chore SFX, and calm HUD as critical-path assets. |
| **Scope explosion** | Years of features arrive before the core loop is fun. | Enforce the one-season, three-resident, three-facility, one-biome, one-boss gate. |
| **Storage identity rename** | Native or browser saves appear lost. | Retain existing storage identity until an explicit copy-and-verify migration; never silently change `user://` paths. |
| **Asset rights** | Rebrand ships content without clear redistribution rights. | Maintain source manifests, hashes, generation records, and owner confirmation before commercial release. |
| **Explicit Web export filters** | Editor works but PCK omits crops/data/assets. | Compare required catalogs with exported pack content from the first farming asset onward. |

## 15. Concept design deck direction

The accompanying concept deck uses six cinematic scenes generated with GPT Image 2:

1. **A Machine Wakes to Green** — the woodland clearing, Protos, fixed safehouse, pond, farm apron, and four gates.
2. **One Cell, One Intention** — precise tool targeting, soil states, sprouts, watering, and a quiet farming HUD.
3. **The Clearing Learns Your Name** — before/after settlement restoration with three facilities and residents.
4. **Four Gates, Four Promises** — woodland center opening into retained wetland, frozen, desert, and volcanic identities.
5. **Danger Has an Address** — Ironjaw's authored desert lair and the farm-changing Burrow Core reward.
6. **Tomorrow Is a Promise** — shipping, sleep settlement, forecast, autosave trust, and morning growth.

These are art-direction targets, not runtime screenshots. Their job is to align mood, composition, color, world density, and the relationship between farm and wilderness before implementation art is produced.

## 16. Final recommendation

Approve the pivot with one non-negotiable production order:

1. **Protect compatibility and ownership.**
2. **Build the safe woodland clearing.**
3. **Separate tools from combat.**
4. **Prove the complete first farming day.**
5. **Make persistence authoritative and interruption-safe.**
6. **Make the homestead lovable.**
7. **Reconnect one purposeful wilderness arc.**
8. **Expand only after measured evidence.**

The smallest honest test is not another monster or another biome. It is whether planting, sleeping, harvesting, shipping, and upgrading in the clearing creates a stronger urge to begin tomorrow than the current relay loop creates to begin another run. If that heartbeat works, the repository already contains enough dangerous world to sustain a remarkable farming RPG. If it does not, we will have discovered the problem before building a festival calendar with 400 localized lines about turnips.

## References

[1]: https://github.com/junnyboi/proto-isometric/blob/98663d7b2e762ec9984d72ff0c6594b960ba6d84/README.md "Proto Isometric repository README"
[2]: https://github.com/junnyboi/proto-isometric/blob/98663d7b2e762ec9984d72ff0c6594b960ba6d84/project.godot "Godot project configuration"
[3]: https://github.com/junnyboi/proto-isometric/blob/98663d7b2e762ec9984d72ff0c6594b960ba6d84/scripts/infinite_world.gd "Deterministic streamed world authority"
[4]: https://github.com/junnyboi/proto-isometric/blob/98663d7b2e762ec9984d72ff0c6594b960ba6d84/scripts/isometric_map.gd "Field composition, controls, and runtime integration"
[5]: https://github.com/junnyboi/proto-isometric/blob/98663d7b2e762ec9984d72ff0c6594b960ba6d84/scripts/save_repository.gd "Save repository and schema validation"
[6]: https://github.com/junnyboi/proto-isometric/blob/98663d7b2e762ec9984d72ff0c6594b960ba6d84/scripts/run_state.gd "Current run-state authority"
[7]: https://github.com/junnyboi/proto-isometric/blob/98663d7b2e762ec9984d72ff0c6594b960ba6d84/scripts/outpost_interface.gd "Outpost services and interface"
[8]: https://github.com/junnyboi/proto-isometric/blob/98663d7b2e762ec9984d72ff0c6594b960ba6d84/scripts/outpost_visuals.gd "Ancient ruin visual catalog"
[9]: https://github.com/junnyboi/proto-isometric/blob/98663d7b2e762ec9984d72ff0c6594b960ba6d84/scripts/sandworms.gd "Current creature and combat facade"
[10]: https://github.com/junnyboi/proto-isometric/blob/98663d7b2e762ec9984d72ff0c6594b960ba6d84/verify.sh "Repository verification and Web export pipeline"
[11]: https://www.storyofseasons.com/grandbazaar/ "STORY OF SEASONS: Grand Bazaar official site"
[12]: https://www.nintendo.com/us/store/products/rune-factory-4-special-switch/ "Rune Factory 4 Special official Nintendo listing"


## 17. Implementation status

This plan is the executable source of truth for the approved Protos Harvest pivot. A phase is marked complete only after its focused tests, full regression suite, import/boot checks, required visual checks, and fast-forward push to the canonical default branch succeed.

| Phase | Status | Revision / evidence | Notes |
|---|---|---|---|
| **Phase 0 — Baseline, identity seams, and compatibility** | **Complete** | Revision `4c986fa`; baseline and post-change `./verify.sh --release` passed on Godot 4.7.2; Phase 0 focused suite passed **83/83**; exact exported PCK booted successfully | Added stable domain ownership, additive schema 4, neutral farm state, v1/v2/v3 migration compatibility, and explicit fresh-farm / legacy-expedition mode seams. |
| **Phase 1 — Safe woodland clearing** | **Complete** | Phase 1 focused suite passed **32/32**; full smoke passed **1,981/1,981**; 1,000-seed generation invariants, seven-day safety soak, landscape/portrait Xvfb checks, `./verify.sh --release`, Web export, and exact PCK boot all passed | Safe woodland clearing, fixed home and pond, deterministic tree belt, central safety, stateful remote ruins, calm home intel, and legacy compatibility are certified. |
| **Phase 2 — Interaction and rendering seam** | **Complete** | Phase 2 focused suite passed **19/19**; full smoke passed **1,981/1,981**; landscape/portrait Xvfb checks, `./verify.sh --release`, Web export, and exact PCK boot all passed | Stable cross-device commands, exact adjacent targeting, protected friendly targets, separate chore lifecycle, dirty-indexed farm rendering, and diagonal depth seams are certified. |
| **Phase 3 — Day-one farm proof** | **Complete** | Phase 3 focused suite passed **24/24**; Phase 0 passed **83/83**; Phase 2 passed **19/19**; full smoke passed **1,981/1,981**; live save/reload, landscape/portrait Xvfb, `./verify.sh --release`, Web export, and exact PCK boot all passed | Six crops, inventory/storage, stamina, forecast, atomic day advancement, shipping, seed purchase, and one workshop upgrade form a certified first-day loop. |
| **Phase 4 — Authoritative persistence and economy** | Pending | — | Begins only after Phase 3 is pushed. |
| **Phase 5 — Lovable homestead** | Pending | — | Begins only after Phase 4 is pushed. |
| **Phase 6 — Wilderness bridge** | Pending | — | Begins only after Phase 5 is pushed. |
| **Phase 7 — Certification and expansion gate** | Pending | — | Final release, Web export, WebDev checkpoint, and deployment gate. |

### Phase 0 implementation evidence

**PH-00** pinned the official Godot 4.7.2 stable engine and matching no-threads Web templates already preserved in Manus project files. The unchanged release baseline completed direct import, lint, repository suites, headless smoke, Web export, and exact exported-PCK boot.

**PH-01** raised the stable runtime registry to version 7 while freezing the 71 legacy identifiers and their verified fingerprint. Explicit authoritative contracts now exist for farm state, calendar/weather, inventory/economy, homestead/settlement, tools/interactions, and ecology; owner-scoped mutation checks reject cross-domain writes.

**PH-02** introduced a strict additive schema-4 envelope with a neutral, detached, canonical farm domain. Schema-1 and schema-2 fixtures migrate directly to schema 4. Schema-3 envelopes open through a deterministic in-memory v3→v4 migration, preserve legacy world/run/profile semantics, retain the original file until a normal save, and quarantine schema 5 as future data.

**PH-03** added stable `fresh_farm` and `legacy_expedition` gameplay modes plus the immutable v3→v4 migration token. Existing active runs remain resumable, while fresh saves have a neutral clearing boot seam ready for Phase 1 without changing the visible legacy field yet.

### Phase 1 implementation evidence

**PH-04 / PH-05** add a pure seeded `WoodlandClearing` classifier and the explicit generation order `base terrain → biome → clearing → protected paths/apron → obstacles → mutations → structures`. Across 1,000 seeds, the exact 6×6 apron, four two-cell gates, protected routes, tree belt, fixed home, and pond remain unobstructed or blocked according to contract. Nine pre-edit external biome/surface golden cells remain exact.

**PH-06** renders GPT Image 2 woodland grass, broadleaf trees, conifers, and pond through the existing streamed terrain/object batching. No per-tree Nodes are allocated. Farm soil is cataloged for later phases without creating plot state, and desert atmosphere is suppressed only inside the fresh-farm clearing.

**PH-07** centralizes safe-home decisions in `WorldSafety`. Spawn, pursuit, projectile, moving hazard, deep weather, and lava adapters all deny harm inside the home boundary; a bounded seven-day-equivalent soak reports zero home violations while legacy expeditions retain their original danger model.

**PH-08** establishes the starting safehouse as discovered, repaired, powered, and service-active. Remote ruins remain landmarks until both repaired and powered, then provide sanctuary and services through explicit state. Legacy starter outposts keep their previous active semantics.

### Phase 2 implementation evidence

**PH-09 / PH-10** add fifteen stable keyboard, controller, and touch intents while retaining the original WASD, Shift, Space/J/K, X/shoulder, Smash, joystick, and camera behavior. A pure resolver maps all eight facings to one exact adjacent cell, applies deterministic target priority, and returns sealed valid/rejected results. The live field composes the target controller through a separate bridge so the capped map authority remains unchanged.

**PH-11** separates tool preview/contact from Walker combat impact. GPT Image 2 anchor art and locked-camera video carriers supply eight-frame hoe and watering sheets; their presenter emits one contact frame, hides/restores the base Walker cleanly, consumes no resources, and mutates no farm state. Explicit policy denies tool damage against crops, residents, friendly fauna, machines, and the home.

**PH-12 / PH-13** add a future farm renderer that consumes chunk-indexed immutable records, redraws only on visible invalidation, allocates no per-crop Nodes, and renders only registered textures. Stable diagonal depth keys cover one-cell tree/crop/resident/Walker foot anchors and multi-cell structures; the existing world-object batch now traverses cells in the same deterministic order.

### Phase 3 implementation evidence

**PH-14** introduces stable item definitions across ten categories, detached robot/home inventory candidates, stack and slot caps, conservative transfers, overflow rejection, and persistence-failure rollback. Fresh farms receive bounded starter contents while migrated legacy farms remain exactly neutral.

**PH-15 / PH-16** implement sparse chunk-indexed plots, tilling, watering, planting, four growth stages, deterministic exact-once harvest, six data-driven crops, five tool definitions, stamina spending/recovery, and bounded hold-repeat. GPT Image 2 crop anchors were animated through locked-camera video carriers and render from four-frame atlases with no per-crop Nodes. A live plot persists through repository teardown and map reload.

**PH-17 / PH-18** add deterministic year, season, day, time, current weather, and next-day forecast. Day advancement is a fixed-order detached candidate—rain, growth, shipping settlement, calendar, recovery—with immutable day and settlement tokens; failed persistence or retry cannot partially apply or duplicate results.

**PH-19** adds generated shipping, storage, and workshop props, Mirelo-style hoe/water/harvest/shipping SFX, daily shipping settlement, seed purchasing, and one watering-efficiency upgrade. Automated and live-input smoke complete till → plant → water/grow → harvest → ship → sleep → buy/upgrade paths, while the exact Web pack includes every new authority and passes boot.
