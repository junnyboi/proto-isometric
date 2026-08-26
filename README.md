# Protos Harvest

**Protos Harvest** is a Godot 4.7.2 isometric farming and wilderness simulation set in a harsh machine-haunted world. Protos wakes in a safe woodland clearing, cultivates a persistent farm, restores scattered ruins into useful facilities, befriends new residents, raises engineered livestock, and prepares for dangerous expeditions through the surrounding desert, wetlands, frozen reaches, and lava fields.

The redesign deliberately preserves the project’s strongest foundations. Deterministic streamed tiles, safehouse ruins, resources, monsters, combat, biomes, responsive controls, schema migration, and Web export remain active. The former Walker’s Wake expedition is now the hostile wilderness layer beyond the homestead rather than the entire game.

## Core loop

A fresh record begins beside the repaired home in the woodland clearing. Players till the six-by-six farm apron, plant one of six crops, water plots, harvest produce, ship goods, and sleep to advance a deterministic day transaction. Weather and crop affinity matter; day advancement atomically handles crop growth, water reset, shipping settlement, machine progress, stamina recovery, applicant lifecycle, resident arrivals, and the next forecast.

Farm income and recovered wilderness materials restore three nearby ruins: **Lyra’s greenhouse and seed shop**, **Rook’s workshop**, and **Mira’s clinic and kitchen**. Repair and power state is persistent and exactly synchronized with the ruin registry. Residents follow deterministic clear-weather and rain schedules, unlock services only after their facilities are active, and support once-per-day conversation, gifts, relationship hearts, and bounded requests.

The homestead can support three engineered domestic species: the **Mossback Grazer**, **Coilhen**, and **Rustsnout Rooter**. Feeding, petting, and product collection use exact-once daily tokens, bounded animal capacity, and persistent bond state. Furnace and irrigation installations extend the farm’s machine and upgrade economy without bypassing the shared transaction boundary.

The repaired workshop now opens a seven-blueprint construction planner for shelter, storage, gathering, fabrication, and fishing infrastructure. Placement previews rotate over canonical footprints, reject actors, crops, machines, trees, water, protected routes, and corridor cuts, then debit one material bill through the exact-once settlement transaction boundary. New sites begin as GPT Image 2 scaffolds, complete after one authoritative sleep, block movement immediately, and support terminal-driven inspect, move, upgrade, and explicitly confirmed partial-refund demolition actions.

The wilderness now projects deterministic **finite salvage clusters and mineral seams** plus **managed renewable biomass patches**. Each source has a stable SHA-256-derived identity, visible rich/depleted/exhausted or renewing phases, bounded sparse persistence, and a sealed **E** terminal with truthful tool, stamina, reservation, and renewal reasons. Manual gathering commits depletion, reward credit, stamina spend, and one receipt atomically. Completed extraction buildings preview compatible source range; ordinary sleep never restores finite deposits, while managed biomass renews only on its scheduled dawn and compacts back to its deterministic default.

After the safehouse and at least one protected bed are available, the settlement may receive one authored human applicant every seventh dawn. Offers remain open for three days and can be **invited**, **declined**, or **deferred for one day** without coercive queueing or hidden penalties. Invited settlers receive a unique protected bed before admission and remain distinct from Lyra, Rook, and Mira. The native Stewardship modal shows each person's portrait, biography, traits, needs, work preferences, and expiry, then provides an exact roster for assigning at most one compatible completed site slot and one of two non-overlapping shifts. Work remains optional; recovering settlers, unsafe housing, stale offers, stale roster revisions, duplicate slots, and incompatible jobs fail without mutation.

Assigned extraction settlers now resolve one deterministic shift during the closing-day transaction. A safe, powered work site selects one compatible in-range deposit, reserves and consumes exactly one source charge, and stores the authored yield in that building's bounded local output rather than teleporting it into global inventory. Reservations block manual gathering until later logistics move the stock. Every productive or idle shift persists a canonical report and exact-once receipt; the roster distinguishes **working**, **output ready**, **resting**, **recovering**, and explicit idle reasons such as unsafe site, no worker, full output, reserved source, exhausted source, or no compatible source. Unassigned active settlers can contribute bounded integer work to construction while Protos always supplies the baseline work unit, so automation helps without removing the player from the loop.

Completed field warehouses now generate a canonical transfer queue ordered by **priority, age, source, destination, and item**. Compatible warehouse workers spend only the capacity actually moved across jobs, while a small bounded self-haul fallback prevents deadlock without hiding output loss; absent warehouses leave extraction output safely at its source. The Logistics & Production tab exposes explicit delivery, per-item warehouse reserve floors, and fabricator policies for enabled recipes, priority, and target stock. Fabricators use staffed shifts, deterministic ingredient alternatives, bounded input/output buffers, recipe duration, and authored byproducts. Automated consumption honors reserves and shared in-flight targets, while construction and direct player actions remain explicit exceptions. All transfer and production state is exact-once, cold-reloadable, and compacted within shared receipt quotas so history saturation cannot block sleep.

Settler wellbeing now resolves explainable daily morale from protected shelter, equitable field rations, rest, safe work, clinic care, worker voice, and belonging. Unsafe shifts stop without output or morale punishment. Deterministic injuries are always nonfatal, suspend work, and recover on an exact advertised day; a repaired powered clinic shortens recovery. Every concern names a concrete remedy in the wrapping roster detail pane. Low morale opens a two-day remedy window rather than an eviction path, and successful remedies cancel notice. If concerns remain unresolved, a settler may depart voluntarily; housing, work, and shift links are cleaned atomically, bounded departure history prevents coercive re-recruitment, and Lyra, Rook, and Mira remain untouched.

## Controls

Use **WASD** or the **arrow keys** to move and hold **Shift** to run. Press **E** for context interactions, **G** for a uniquely safe Quick action, **F** to use the selected farming tool, **Q/R** to cycle tools, **I** for inventory, **M** for the journal/map, **+/-** to zoom, and **Space**, **J**, or **K** for the preserved combat Smash. The safehouse, eligible completed work sites, and admitted settlers expose the Stewardship applicant/roster terminal through **E**; completed warehouses and fabricators open its Logistics & Production tab directly. Quick never performs applicant, workforce, logistics-policy, or forced-delivery decisions. Controller and touch commands map to the same stable intent catalog. Mobile presents a floating movement joystick plus an eight-slot command dock with Context, Tool, Quick, Cycle, Inventory, Journal, Cancel, and the preserved Smash control.

The title screen and field layout adapt between landscape and portrait viewports. Gameplay opens directly into the field without tutorial cards, training overlays, tutorial timers, or training controls in Settings. Accessibility settings include UI scale, reduced flash, camera shake, haptics, left-handed controls, effects quality, and independent Master, SFX, Music, and Ambience levels.

## World and progression

The home clearing is deterministic and safe: a fixed pond, central home, farm apron, path exits, surrounding trees, and no enemy or hazard spawns inside the protected sanctuary. Existing biomes remain reachable as expedition territory. Their monsters, hazards, resources, safehouses, objectives, Alert encounters, Impact Charge combat, Refit modules, and extraction rules remain regression-protected for legacy saves and future wilderness progression.

Home time uses deterministic day, night, and rain music with bounded equal-power crossfades. Remote biomes keep their established two-track music system. Generated game and UI art uses GPT Image 2; chore and livestock animation sheets come from locked-camera video carriers; farm sound effects come from the approved image-to-video-carrier audio workflow.

## Runtime architecture

The runtime uses stable command intents, a pure adjacent-cell resolver, batched dirty-indexed farm and homestead rendering, deterministic diagonal depth, and no per-crop, per-resident, per-settler, or per-animal scene nodes. Farming, inventory, economy, machines, upgrades, facilities, relationships, requests, livestock, applicant, housing, and workforce mutations all validate detached candidate snapshots and persist through one cross-domain transaction boundary.

Schema-5 persistence preserves legacy schema-1/2/3/4 migration while adding bounded settlement sections, exact-once receipts, canonical gameplay revisions, section budgets, recoverable validated temporary saves, and an honest browser-storage capability warning. The retired tutorial field remains a neutral validated compatibility slot so existing saves load without migration loss, but no runtime system reads or writes it. Save validation enforces exact keys, hard collection caps, canonical sorting, stable IDs, coordinate bounds, duplicate rejection, atomic primary/backup replacement, and quarantine for malformed or future data.

## Develop and verify

```bash
$HOME/bin/godot --path .
./verify.sh
```

For a clean no-threads Web release:

```bash
./verify.sh --release
```

The release command runs import, lint, repository tests, bounded headless boot, Web export, and exported-PCK boot checks. It writes the required HTML, JavaScript, WASM, PCK, audio worklets, icons, and splash assets to `/home/ubuntu/proto-isometric-build/web`.

## Project references

- [Protos Harvest implementation plan](docs/plans/PROTOS_HARVEST_IMPLEMENTATION_PLAN.md)
- [Walker’s Wake legacy plan](docs/plans/WALKERS_WAKE_IMPLEMENTATION_PLAN.md)
- [Gameplay proposal archive](docs/concept/gameplay-v2/GAMEPLAY_ENHANCEMENT_PROPOSAL.md)
- Source repository: https://github.com/junnyboi/proto-isometric
