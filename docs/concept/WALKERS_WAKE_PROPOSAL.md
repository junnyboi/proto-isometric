# WALKER’S WAKE

**Game concept and 2:1 isometric prototype proposal**
Author: Manus AI

![WALKER’S WAKE key art](walkers-wake-key-art.jpg)

## Proposal

**WALKER’S WAKE** is a desert exploration and route-planning game about a colossal utility robot that has become a moving home. The player does not simply pilot a mech. They guide a fragile settlement carried inside it, choose where the giant walks, decide when it kneels, and live with what its footsteps uncover or destroy.

The recommended design combines three compatible fantasies: **crossing a dangerous landscape**, **maintaining a town-sized machine**, and **excavating a buried machine civilization**. Combat can exist later, but it should create route pressure rather than become the game’s identity. The robot is most interesting as infrastructure with legs, not as a conventional weapons platform. The desert already has enough things trying to kill everyone; it does not require another audition.

## Player Fantasy

The player acts as the Walker’s route keeper. From a fixed 2:1 isometric view, they survey terrain, plot a path, and watch the giant settlement advance tile by tile. Every stride costs power and water, creates shelter in its shadow, leaves a traversable wake for the caravan, and can expose buried ruins. The central tension is that **movement is survival, but every movement has consequences**.

The robot should feel enormous without forcing the player to manage thousands of citizens individually. Decisions happen at three readable scales: choose a route across the map, configure a handful of machine systems, and respond to discoveries or crises through compact events.

## Recommended Core Loop

| Phase | Player decision | Resulting tension |
|---|---|---|
| Survey | Read dunes, salt, rock, ruins, storms, and resource signals | The shortest route is rarely the safest or richest |
| Plot | Choose a destination and preview energy, heat, and stability costs | Committing the Walker makes future terrain matter |
| Walk | Advance while systems consume resources and the caravan follows | A moving home cannot repair everything at once |
| Leave a wake | Footprints reveal buried machinery, create paths, or damage fragile sites | Progress changes the desert permanently |
| Kneel | Stop to deploy crews, trade, condense water, repair, and excavate | Remaining stationary attracts storms, raiders, or structural heat |
| Decide | Integrate discoveries, help settlements, or abandon opportunities | The Walker’s identity and the region’s future diverge over time |

## Why This Could Be Fun

The robot gives the map a persistent moving center. Traditional base-building asks where to construct a permanent home; WALKER’S WAKE asks **when home should move and what must be left behind**. Route selection becomes meaningful because terrain affects the machine differently, while the wake system turns traversal into world modification rather than empty travel time.

The design also supports satisfying visual feedback. A single chosen route can animate across the diamond grid. Each heavy step can deform sand, expose turquoise machine strata, throw a moving shadow over caravans, and alter traversal costs. Kneeling can transform the same robot from traveler to temporary town, making one object carry both exploration and settlement mechanics.

## Concept Options Considered

| Direction | Strength | Risk | Recommendation |
|---|---|---|---|
| Route-planning survival | Clear decisions, strong map use, easy to prototype | Could become spreadsheet-heavy | Use as the mechanical spine |
| Town-on-legs management | Distinctive fantasy and meaningful upgrades | Can overwhelm the journey | Keep to 4–6 major systems, not citizen micromanagement |
| Archaeological mystery | Gives every route discovery value | Requires sustained narrative production | Use modular ruins and event chains |
| Mech combat tactics | Immediate spectacle | Makes the concept more generic and expensive | Keep combat rare, positional, and avoidable |

The recommended hybrid is **route strategy + compact moving-city systems + archaeological discovery**. A run or campaign should be remembered by where the Walker went, what it awakened, and which communities survived in its wake.

## Visual Direction

![2:1 isometric gameplay target](walkers-wake-gameplay-target.jpg)

The visual language uses ochre sand, rust-red shelves, bone-white machinery, charcoal ruins, oxidized teal signals, and amber selection states. Terrain must remain readable before it becomes beautiful. The fixed orthographic 2:1 projection should keep tile diamonds exact, while atmospheric dust is reserved for the horizon and map edges so it never obscures route decisions.

The Walker should be asymmetrical, repaired, and inhabited. Scaffolds, condensers, cargo cranes, solar cloth, lights, and attached structures communicate that people depend on it. Weapons should not dominate its silhouette. At gameplay scale, one bright sensor, the pale shell, teal panels, and long legs are enough to recognize it.

## Implemented Technical Foundation

The current Godot increment establishes the map as a procedural system rather than committing prematurely to a finished tileset.

| Capability | Current implementation |
|---|---|
| Projection | Exact 2:1 diamond transform using 90×45 logical tiles |
| Grid | Deterministic 9×9 desert test map |
| Terrain | Sand, salt, rock blockers, and machine ruins |
| Interaction | Mouse hover, click destination, arrow-key step, Escape return |
| Navigation | Four-direction AStarGrid2D routing around blocked terrain |
| Actor | Procedural giant robot that autonomously wanders and follows selected routes |
| Feedback | Teal route line, amber destination, hover outline, robot status panel |
| Rendering | Procedural CanvasItem drawing with no art dependency |

The procedural renderer is intentional. It lets tile size, traversal, elevation, robot footprint, and map readability change cheaply. Once the rules stabilize, the renderer can move to `TileMapLayer` or authored tile scenes while preserving the same grid coordinates, picking, and navigation APIs.

## Smallest Playable Roadmap

### Increment 1 — Route and Wake

The player selects a destination, previews a route, and spends a simple energy budget per tile. Every completed step marks a footprint tile. Some footprints expose salvage. This is the fastest test of whether watching and directing the Walker is satisfying.

### Increment 2 — Heat Versus Water

Walking raises reactor heat; kneeling condenses water but allows a dust front to approach. The player chooses between continuous movement and profitable stops. Two resources are enough to create route tension without converting the prototype into municipal accounting software.

### Increment 3 — Kneeling Mode

At selected safe tiles, the Walker lowers into a temporary settlement. The player allocates limited crew capacity among repair, salvage, water, and helping a nearby caravan. The same map remains active, but time pressure changes.

### Increment 4 — Buried Signal

Ruins form a small linked mystery. Excavated machine fragments alter the Walker: improved cooling, longer stride, safer rock traversal, or a controversial autonomous behavior. This provides progression and a narrative reason to deviate from efficient routes.

## Success Test for the Concept

The concept is promising if a short session creates three emotions without requiring combat: satisfaction from plotting a good route, affection for the Walker as a home, and curiosity about something uncovered by its passage. If route choice feels trivial, add terrain pressure before adding more systems. If the Walker feels like a cursor, make each step change the world. If resource management dominates the experience, delete numbers before inventing new ones.

## Immediate Recommendation

Build **Increment 1 — Route and Wake** next. Add a visible energy meter, persistent footprint tiles, and a 20% deterministic chance for a footprint over machine-bearing terrain to reveal salvage. That slice will test the defining mechanic in a single short loop and tell us whether the desert needs more survival, more mystery, or—if all else fails—an irresponsible amount of robot wrestling.
