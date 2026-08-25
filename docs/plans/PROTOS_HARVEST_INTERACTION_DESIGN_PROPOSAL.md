# Protos Harvest
## Universal Interaction and Farming-RPG Expansion Proposal

**Author:** Manus AI  
**Product direction:** Post-apocalyptic robot farming simulator with deterministic wilderness combat  
**Canonical repository:** [junnnyboi/proto-isometric](https://github.com/junnyboi/proto-isometric)

## 1. Design thesis

Protos Harvest should feel like a single coherent world rather than a collection of separate farming, settlement, and combat systems. The unifying rule is simple:

> **The highlighted adjacent tile is the interaction authority. Pressing E opens a state-aware menu for everything anchored to that tile; a second explicit confirmation performs the selected action.**

The menu never guesses on the player’s behalf. It previews available actions, requirements, costs, consequences, and disabled reasons. This converts the existing farming, machines, ruins, residents, livestock, ecology, hazards, and legacy expedition systems into one discoverable interaction language without weakening deterministic saves or exact-once transactions.

The cyan target diamond remains the only persistent spatial marker. The decorative arrow below the player is removed. Combat remains intentionally separate: **Context inspects and converses; Tool performs productive work; Smash attacks hostile targets.**

**GPT Image 2 concept:** Universal tree interaction menu, delivered with the design package.

## 2. Player experience

Approaching a tree and pressing E opens **Tree** actions such as **Chop Down**, **Admire**, and **Inspect**. Approaching grass opens **Till Land**, **Plant Seeds**, **Water**, and **Inspect Soil**, with choices enabled only when the current state permits them. Buildings expose their services; residents expose conversation, gifts, requests, and relationship information; animals expose care and products; machines expose recipes and claims; wilderness threats expose inspection and tracking while Smash remains the explicit combat command.

The opening E press is always non-destructive. Selection and confirmation are separate. Disabled entries remain visible with a concise reason, making the world legible instead of mysteriously refusing input.

## 3. Interaction grammar

| Intent | Default inputs | Responsibility | Mutation timing |
|---|---|---|---|
| **Context** | E / controller A / touch Context | Open the menu, inspect, converse, collect, operate services | Only after explicit row confirmation |
| **Tool** | F / controller Y / touch Tool | Use equipped hoe, watering tool, axe, or pick | At the verified animation contact frame |
| **Smash** | Space, J, K / controller combat inputs / touch Smash | Damage hostile actors only | Existing combat contact rules |
| **Cancel** | Escape / controller B / touch Cancel | Close the top modal without leaking input | Never mutates gameplay |

The same adjacent cell and target snapshot drive all three intents. Device-specific details never enter gameplay state.

## 4. Target and action matrix

| Target family | Representative Context options | Tool or combat behavior |
|---|---|---|
| Walkable terrain | Inspect soil, Till Land, Plant Seeds | Hoe tills eligible land; other tools reject cleanly |
| Empty or occupied plot | Inspect, Plant, Water, Harvest | State-aware farm operation at one contact/commit |
| Broadleaf or conifer tree | Chop Down, Admire, Inspect | Axe only; completion records one canonical clear and wood reward |
| Rock, ore, salvage node | Mine/Break, Inspect | Pick only; completion grants declared material exactly once |
| Loose item or scrap | Collect, Inspect | Pickup has highest Context priority; full capacity leaves it untouched |
| Home | Sleep, Storage, Inspect Safehouse | No destructive tool action |
| Shipping bin | Ship selected, Ship all, Review staged value | Settlement remains part of atomic sleep |
| Storage and seed shop | Open inventory, Buy seeds, Inspect stock | Seed options derive from catalog and owned money |
| Workbench and furnace | Inspect state, Start recipe, Claim output, Upgrades | Recipe and token rules remain exact-once |
| Facility ruin | Inspect, Repair, Power | Repair precedes power; state mirrors the ruin registry |
| Remote ruin | Inspect, Review sanctuary, Activate when eligible | No protection before authoritative activation |
| Resident | Talk, Give Gift, View Request, Use Service, Relationship | Menus do not consume daily tokens until confirmed |
| Livestock | Inspect, Feed, Pet, Collect Product | Tools and Smash are denied |
| Friendly wilderness herd | Observe, Bond, Collect renewable material | At most one yield per habitat/day; cannot be attacked by ordinary tools |
| Hostile creature or boss | Inspect threat, Review drops, Track habitat | Smash remains the only default damage action |
| Hazard opportunity | Inspect forecast, Review mitigation, Stabilize | Time-window and capability gated; reward token exact-once |
| Expedition gate | Review biome, Review cargo/risk, Enter | Legacy relay/Alert/Impact/extraction semantics stay intact |

**GPT Image 2 concept:** Farm-tile action and seed-selection menu, delivered with the design package.

## 5. Left-side interaction menu

The menu uses a single pooled Control tree rather than one node per world object. It opens against the left safe area, retains the world view, and scales between landscape and portrait layouts. The title identifies the authoritative target. Rows show a stable label, icon, binding or tool, cost preview, and disabled reason.

Keyboard Up/Down and controller D-pad move focus without wrap. Enter, E, Space, or controller A confirms. Escape, controller B, touch Cancel, or tapping outside closes. Touch may select rows directly and scroll long lists. Opening any modal cancels held movement, Tool, and Smash inputs and discards pending contacts.

The menu state machine is:

1. **Closed:** target diamond follows facing.
2. **Open ready:** a current snapshot is displayed; first enabled row is focused.
3. **Open blocked:** disabled reason is visible; only navigation and close are accepted.
4. **Executing:** duplicate accepts are suppressed.
5. **Result:** success closes or refreshes; stale or rejected actions refresh with the sealed reason.

**GPT Image 2 concept:** Resident and homestead interaction menu, delivered with the design package.

## 6. System architecture

The implementation adds runtime-only interaction descriptors and offers. Providers project existing authorities into a chunked cell index. They may read but cannot mutate, save, inspect device input, or instantiate world nodes. The resolver applies a total deterministic order and produces a sealed menu snapshot. On confirmation or tool contact, the executor re-reads the committed state and requires the same provider, action, target, and anchor identity before building one detached mutation.

Every productive action crosses exactly one validated persistence boundary. Presentation, audio, dirty cells, rewards, and UI updates occur only after acknowledgement. A stale target, invalid tool, exhausted token, full inventory, failed write, or failed publish costs nothing.

Runtime interaction data is not serialized. Existing schema-4 keys, schema-1/2/3 migrations, `user://walkers-wake-world.json`, legacy expedition meanings, and the two-megabyte save limit remain unchanged.

## 7. Farming and life-sim depth

The universal menu exposes the substantial simulation already present and establishes clear future expansion seams:

| Pillar | Launch behavior | Expansion seam |
|---|---|---|
| Crops | Six crops, four stages, watering, deterministic yield, Coilbean regrowth | Fertilizer, crop quality, greenhouse seasons |
| Homestead | Home, three repairable/powerable facilities, shipping, storage, machines | Construction permits and cosmetic restoration |
| Community | Lyra, Rook, Mira, schedules, talk, gifts, requests, services | More residents, branching stories, festivals, romance |
| Livestock | Mossback, Coilhen, Rustsnout care, bond, products | Breeding, illness, animal traits |
| Wilderness | Twelve habitats, four hazards, useful materials, Ironjaw | Additional authored bosses and biome arcs |
| Robot progression | Tools, chassis, storage, irrigation, power, furnace, capabilities | Modular attachments and specialized farm/combat builds |
| Economy | Shipping, seed purchase, recipes, upgrades | Contracts, market variation, regional trade |

Deferred breadth—fishing, romance, festivals, crop death, breeding, tree planting, freeform demolition, and new seasons—should be built only after the universal interaction authority is stable. This keeps the architecture shippable instead of lovingly constructing a deterministic swamp.

## 8. Wilderness-to-farm progression

Combat is valuable because it improves the farm, not because it replaces farming. Each biome provides routine materials and one prepared hazard material that together unlock a farm capability. Ironjaw’s exact-once Burrow Core unlocks the well and deep tilling. Context menus explain these links before the player commits to danger.

**GPT Image 2 concept:** Wilderness-to-farm interaction and progression view, delivered with the design package.

## 9. Accessibility and localization

Every action, target name, cost, binding hint, and rejection reason receives English and Simplified Chinese keys with exact placeholder parity. Focus traversal works without a mouse. Touch regions never overlap the joystick or Smash control. Disabled states combine icons, labels, and reasons rather than relying on color. Reduced flash, shake, haptics, effects quality, handedness, audio controls, and responsive orientation remain respected.

## 10. Success criteria

The redesign is successful when the player can approach every visible launch target and receive either a complete deterministic action menu or an explicit noninteractive explanation; when E never performs an irreversible action on its opening press; when the foot arrow is absent from native, Web, and legacy modes; when productive actions remain exact-once across failure and reload; and when the entire game still passes its Godot 4.7.2 release, exported-PCK, and served-browser gates.

## References

[1]: https://github.com/junnyboi/proto-isometric "Protos Harvest canonical repository"
