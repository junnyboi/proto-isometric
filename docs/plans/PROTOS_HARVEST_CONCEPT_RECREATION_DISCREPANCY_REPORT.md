# Protos Harvest Concept Recreation Discrepancy Report

**Canonical repository:** `/home/ubuntu/workspace/proto-isometric`
**Pinned revision:** `8e0d04f19dd60558d7b4d6d65bc7e227d5d30f46`
**Concepts assessed:** Landscape terrain dossier, landscape object dossier, and portrait mobile dossier
**Assessment date:** 2026-08-27
**Purpose:** Define what can be recreated visually, what is already supported mechanically, and what must remain absent until an authoritative gameplay source exists.

> **Governing rule:** The concepts are visual and information-architecture targets. They are not specifications of current game state. Every displayed fact, number, lock, cost, distance, action, preview, history item, and result must originate from a validated canonical snapshot, option, execution result, or newly approved authority.

## 1. Executive assessment

A close recreation is feasible **without replacing the interaction system**. The canonical revision already contains the most important correctness foundations: digested menu snapshots with exact keys, closed operation descriptors, typed and bounded inspection results, stale-option rejection before execution, exact-once mutation boundaries, pooled responsive UI, keyboard/pointer/controller/touch support, bilingual localization parity, modal suppression, and thread-free Web export constraints.[1][2][3][4][5]

The principal discrepancy is not color or styling. The concepts present substantially more domain data and more operations than the game currently owns. The terrain concept invents health, ecology, soil, moisture, resource yields, traversal cost, hazards, and nearby distances. The object concept invents a machine identity, percentage integrity, repair stage, network state, throughput, ownership, maintenance history, faults, a blueprint, and a nearby power node. The portrait water concept invents depth, quality, habitat abundance, weather effects, safe traversal, Sample Water, Fill Tool, Place Pump, and Mark Waypoint operations, several costs, and a success outcome. Canonical revision `8e0d04f` emits real **Cast Line** and **Cast with Luminous Bait** fishing options, including truthful tool/bait reasons. Unsupported claims still cannot be copied into presentation code.

The correct scope is therefore an **evolution of `HarvestInteractionPresenter` over the sealed interaction contracts**. Desktop may adopt the concepts’ dossier hierarchy, dual panes, target linkage, and bounded nearby-interest card. Portrait may adopt a world-preserving bottom sheet with Summary, Actions, and an authority-backed History view. Unsupported sections must be omitted, disabled with a truthful reason, or deferred—not filled with plausible mock-up content.

## 2. Audited baseline and strengths to preserve

| Area | Canonical behavior at `8e0d04f` | Recreation constraint |
|---|---|---|
| Target/menu identity | `InteractionMenuSnapshot` has eight exact keys, canonical target state, sorted unique options, and a deterministic snapshot digest.[1] | Do not append decorative keys or raw runtime objects to the signed menu contract. Build a separate bounded presentation projection. |
| Option authority | `InteractionOption` owns provider, operation, arguments, enablement, localized label/reason, priority, affected cells, costs, and close behavior.[2] | Action cards may restyle these fields but must not override them. Descriptions/icons are presentation metadata only. |
| Operation safety | `InteractionOperationCatalog` distinguishes read-only, UI-only, and mutating routes. Reads/UI transitions have no persistence or receipt; mutations require persistence domains and snapshot-plus-revision staleness policy.[3] | Every new action must be registered vertically through the appropriate authority. No presenter callback may become a mutation path. |
| Confirmation | `HarvestInteractionController.confirm_menu()` re-resolves before execution, rejects a changed snapshot for that press, restores stable `action_id`, blocks disabled rows, and gates duplicate execution.[4] | All pointer, key, controller, touch, optional one-tap-read, and hold-completion paths must end at this one gateway. |
| Inspection | `InteractionExecutionResult` is an exact ten-key, digest-validated record; its view is bounded to twelve typed localized facts.[5] | Rich sections may project validated facts, but cannot weaken exact keys, caps, typed values, or digest checks. |
| Presenter | One pooled `CanvasLayer` supplies a dark teal/amber terminal, bounded scroll areas, 44 px controls, compact tabs, locale refresh, and a 150 ms duplicate-activation debounce.[6] | Reflow this presenter; do not introduce a competing dossier modal with separate input ownership. |
| Modal ownership | Opening the menu stops movement and yields HUD radar; mobile controls and camera gestures are suppressed; Cancel/Back is consumed before map fallback.[4][6][7][8] | A visible world aperture remains modal and non-playable. Target overlays must ignore input. |
| Rendering/Web | Stable objects are drawn through one visible-cell batched renderer; HUD state/layout skip unchanged work; Web uses GL Compatibility, no threads, and explicit resources.[9][10][11] | No per-target world nodes, per-frame world scans, live blur, viewport copies, or unbounded alpha textures. |
| Localization | English and Simplified Chinese are exact-key paired and use a CJK runtime font; open-menu locale refresh preserves action identity.[6][12] | Every new visible key and named placeholder must land in both locale files in the same change. |

The focused audit runners passed **19/19 interaction-inspection checks** and **21/21 interaction phase-C checks**. The aggregate baseline was also verified with Godot 4.7.2 and reported **`[SMOKE_PASS] checks=2142`** and **`[PASS] Protos Harvest`**. These are regression floors, not expendable scaffolding.

## 3. Visual discrepancy matrix

### 3.1 Landscape terrain dossier

| Concept target | Current presentation | Discrepancy | Truthful disposition |
|---|---|---|---|
| Tall illustrated dossier with Surface, Soil, and Ecology strata | One left terminal with a textual Decision Card and flat facts | The visual hierarchy, thumbnails, grouped sections, and density are absent. | Recreate the hierarchy with pooled native controls. Ship Surface immediately; render Soil or Ecology only if an explicit authority supplies the section. Omit empty invented strata. |
| Health and ecology status beside identity | Header contains title, subkind, and general result status | No canonical tile health or per-cell ecology stability exists. | Do not show a percentage, grade, or “Stable” label. Add those only after a deterministic bounded service is part of target projection. |
| Tillable/buildable/hazard chips | Current facts show walkable, tillable, and blocked as text | Chip styling is absent; buildability and hazard absence are not certified terrain facts. | Promote real walkable/tillable/blocked values to chips. Buildability must come from `PlacementValidator`; hazard “none” requires a hazard spatial query that certifies absence. |
| Resource meters and movement-cost block | No tile resource vector, traversal class, or movement cost in the terrain target | The concept implies unsupported telemetry. | Omit all meters and numeric movement cost until corresponding authorities exist. Boolean walkability may be shown. |
| Detached outcome preview | Executed read result appears inside the same panel | No pure selected-option preview exists. | Add a pure descriptor/option-backed preview. It may show canonical costs, reason, mutability, affected cells, and explicitly modeled deterministic effects; it may not execute a candidate. |
| Leader line and nearby-interest card | Cyan target diamond exists; no connector or POI card | Spatial binding and bounded nearby context are absent. | Add one cached primitive overlay and a capped index-backed query. Use **tile distance**, not meters, unless a canonical world scale is introduced. |
| Dense 2560×1440 painterly world | Current validated presentation is stylized and less dense at 1280×720 | The target implies a broader art-direction replacement. | Keep the dossier scope separate from world-art replacement. Never ship the concept screenshot as a runtime texture. |

### 3.2 Landscape object dossier

| Concept target | Current presentation | Discrepancy | Truthful disposition |
|---|---|---|---|
| Independent left Object Dossier and right Inspection Results panel | One left panel, capped near 438 px, vertically combining details and actions | Simultaneous dual-pane scanning and central aperture are absent. | Use dual panes only when safe bounds preserve a minimum central aperture; fall back to one side panel or compact tabs at smaller dimensions. |
| Object portrait, status subtitle, icon-led stat rows | Text-only title/subkind and homogeneous fact labels | No portrait slot, status presentation catalog, row groups, semantic icon policy, or dividers | Add a presentation catalog and pooled row controls. Portrait/icon IDs must never imply gameplay state. |
| Ancient Irrigation Machine, Half-Repaired | No such canonical target; closest truthful object is the ancient greenhouse with Boolean repaired/powered state | Concept identity and repair stage are fictional in the current domain. | Use the real localized greenhouse/facility identity and Boolean states, or first add a versioned irrigation-facility domain. Never map `repaired=false` to “Half-Repaired.” |
| Faults, blueprint, nearby source, recommendation groups | Current result view is a flat bounded fact list | The necessary fault, blueprint, and power-topology sources do not exist. | Group only validated read facts and option-derived next actions. Do not render a fault/blueprint/source card until each has an authoritative catalog/query. |
| Rich action cards with descriptions, badges, icons, and hold guidance | One-line/multiline buttons use inferred Unicode glyphs and compact cost/reason text | Presentation metadata and hold state machine are absent. | Add read-only presentation metadata. Any hold UX must call `confirm_menu()` exactly once and must not create actions that providers do not emit. |
| Object ring, brackets, routed connectors, pin | Only the adjacent-cell diamond is present | No sealed-target anchor or connector overlay exists. | Bind one non-interactive overlay to the sealed target cell/stable anchor. A pin may be session-local presenter state only and must clear on close/stale replacement. |

### 3.3 Portrait mobile dossier

| Concept target | Current presentation | Discrepancy | Truthful disposition |
|---|---|---|---|
| Wide rounded bottom sheet retaining approximately the upper half of the world | Tall left-side terminal overlays nearly full height | The current shape obscures spatial context and does not read as a mobile sheet. | Add a bottom-anchored portrait mode with platform safe-area insets and a 38–48% retained world window where viewport height permits. |
| Summary / Actions / History navigation | Compact mode has Details / Actions only | Summary naming and History authority are absent. | Rename Details to Summary. Introduce History only with a bounded authoritative session log; otherwise do not fabricate past events. |
| Side-by-side summary/action composition | Narrow portrait shows one compact tab at a time | The concept density does not fit 390 px or long Chinese text. | Permit a 40/60 split only at sufficient sheet width; use mutually exclusive tabs on narrow devices. |
| Target identity with signed coordinates and map affordance | Coordinates are signed in the menu but hidden; no map/waypoint operation exists | Coordinates are unpresented; map control is unsupported. | Render localized X/Y from `target_cell`. Omit map/waypoint until a real UI-only or persisted operation is defined. |
| Large icon cards with aligned cost/lock columns | Text buttons with numeric index and inferred glyph | Card structure and touch hierarchy differ. | Replace row internals with pooled icon/title/description/cost/reason controls while retaining option identity and focus metadata. |
| Full-width Close footer | Current compact footer uses Back and Activate; outside press and Cancel also close | Visual mismatch, but current flow has stronger keyboard/controller semantics. | Add a touch Close affordance that delegates to controller teardown; retain Back/Activate, Cancel, and tested outside-close policy. |
| Floating result toast | Current feedback is an internal status/result card | Result placement differs. | Add one pooled localized toast sourced only from a validated execution result. |
| Redesigned top HUD/vertical world controls | Current Field HUD and mobile controls have independent canonical state | The concept broadens scope beyond the dossier. | Preserve the existing HUD and make it yield only where overlap requires. Do not invent droplet/leaf meters or replace unrelated controls in this project. |

## 4. Truthful capability boundaries

### 4.1 Terrain and water facts

| Fact or concept claim | Canonical support | Required behavior |
|---|---|---|
| Target cell X/Y | Signed `Vector2i` in the menu snapshot | **Show.** Format with localized coordinate templates. |
| Terrain biome and surface | `biome_id` and `surface_id` | **Show.** Resolve stable IDs through localization/presentation catalogs. |
| Walkable, tillable/farmable, blocked | Canonical booleans for ordinary terrain | **Show.** The audited Woodland Grass tile is tillable; the concept’s “TILLABLE: NO” is a direct contradiction and must not ship. |
| Plot state | Optional authoritative plot projection | **Show only when present.** Use exact plot/crop/water states, not percentages. |
| Water class | `water_class` on stable water | **Show.** “Freshwater Pond” is a class, not proof of “Clean” quality. |
| Water walkability | Canonically `false` for the audited pond | **Show “No.”** Never present “Safe Traversal: Yes.” |
| Irrigation relevance | Canonical Boolean | **Show.** Do not convert it into a radius or bonus. |
| Terrain health, ecology stability, canopy maturity | No per-cell authorities | **Reject and omit.** Artwork, biome, or absence of hazards is not evidence. |
| Soil “Loam” and moisture 38% | No generic soil taxonomy or moisture percentage | **Reject and omit.** A plot’s watered/dry state is not a percentage. |
| Depth 1.8 m, quality Clean, habitat Abundant | No water depth, quality, or abundance model on this target | **Reject and omit.** |
| Weather effect +10% | No water-target weather modifier | **Reject and omit.** |
| Buildable: Conditional | Placement validation exists outside terrain inspection | **Do not infer.** Show only after an adapter returns a result for a defined blueprint/envelope plus localized reason. |
| Hazard: None | No terrain query certifies negative hazard state | **Do not infer absence.** Add a revisioned hazard query first. |
| Resource meters, “Easy,” Move Cost 1 | No terrain yield vector or projected path cost | **Reject and omit.** |
| Nearby POIs in meters | No current bounded query or canonical meter scale | **Reject current labels/distances.** A future index may return capped stable records in tile units. |

### 4.2 Object and facility facts

| Fact or concept claim | Canonical support | Required behavior |
|---|---|---|
| Facility repaired/powered | Boolean state exists for canonical homestead facilities | **Show.** Use provider-emitted values. |
| Greenhouse repair cost | Canonical current cost is **4 wood + 2 stone** | **Show from `cost_preview`.** Do not hard-code it in the presenter. |
| Greenhouse power cost | Canonical current cost is **1 irrigation coil** | **Show from `cost_preview`.** |
| Safehouse-power prerequisite | Canonical upgrade prerequisite exists | **Show only when explicitly emitted/projected.** It is not a spatial power node. |
| Greenhouse/seed-shop services | Canonical services exist when repaired and powered | **Show only from provider/result state.** |
| Ancient Irrigation Machine / Half-Repaired | No such target or staged repair record | **Reject.** A concept image cannot create an entity or repair stage. |
| Integrity 42% | No integrity/durability source | **Reject.** Never derive a percentage from a Boolean. |
| Network Unlinked / Output 0 per day | No network graph or throughput simulation | **Reject.** Powered-off is not network-unlinked, and radius capability is not daily output. |
| Ownership Homestead / Last Service 18 days | No ownership semantic or service timestamp in the target | **Reject.** A domain/location label is not ownership. |
| Pump Rotor Seized / Intake Screen Blocked | No stable fault catalog, diagnostic state, or discovery flags | **Reject.** Never bake concept prose into a result. |
| Irrigation Pump Mk I blueprint, known/owned/compatible | No such construction blueprint | **Reject.** The canonical irrigation-grid upgrade is a different capability. |
| Safehouse Power Node at 18 tiles | Safehouse power is an upgrade prerequisite, not a spatial node | **Reject the node and distance.** |
| Concept repair cost: 3 iron + 1 coil | Contradicts the real greenhouse costs | **Reject.** Only the sealed option cost is authoritative. |
| Mark for Construction / facility Dismantle | Not emitted for ancient homestead facilities | **Do not show.** Construction/demolition remains restricted to its canonical flows. |

> **Explicit non-invention boundary:** No terrain health, ecology score, water depth, water quality, habitat abundance, fault, staged/percentage repair state, concept repair cost, maintenance age, or blueprint fact may be displayed unless a named authoritative source, exact validated contract, persistence/migration policy where needed, localization, and negative tests are added first. Existing Boolean facility repair and provider-owned exact repair costs remain valid; invented repair lore does not.

### 4.3 Actions and outcomes

| Concept action | Current support | Allowed implementation |
|---|---|---|
| Inspect / Inspect Components | Read-only `inspect` and specialized read descriptors exist | Restyle or terrain-label as Survey while retaining read-only semantics, or add a closed `survey_terrain` read descriptor. |
| Survey | No separate operation | Prefer a presentation label over existing Inspect unless behavior genuinely differs. A new operation must remain snapshot-identity-bound and mutation-free. |
| Open Field Guide | Destination/localization exists, but no terrain option route | Add a UI-only descriptor/adapter and respect global external-modal arbitration. |
| Mark Waypoint | No canonical waypoint subsystem | Session-local markers may be UI-only and explicitly nonpersistent. Saved markers require schema/version, revision, receipt/idempotency, migration, and reload tests. |
| Clear Brush | No generic terrain operation | Resolve a concrete stable tree/destructible target and delegate to its existing mutating authority. Never clear abstract terrain or neighbors from a UI callback. |
| Cast Line / Cast with Luminous Bait | Canonical seasonal provider emits both fishing operations with current enablement, reasons, costs, and exact-once mutation routing | **Show when emitted.** Render the sealed option exactly and keep every activation behind `confirm_menu()`. |
| Sample Water / Fill Tool / Place Pump | No canonical water options | Do not render these cards. Each future action requires state/service, operation descriptor, provider option, stale/receipt policy, result, localization, and exact-once tests. |
| Object Repair / Route Power | Supported for the real facility when emitted | Render enablement, reasons, and costs exactly from the sealed option; confirm through the controller only. |
| Hold to dismantle/confirm | No hold-duration contract; facility dismantle unsupported | A presenter-only hold may wrap an already authorized confirmation-required operation, cancel on drift, and call `confirm_menu()` once. It cannot authorize a new action. |
| Result toast | No detached toast; validated results exist | Project only validated `InteractionExecutionResult` keys/parameters. Never claim “Clean Water,” irrigation radius changes, Field Guide updates, or rewards absent from the result. |

## 5. Interaction and platform discrepancies

| Concern | Current behavior | Concept pressure | Non-negotiable boundary |
|---|---|---|---|
| Opening | Context opens a sealed non-mutating menu; Inspect is explicit | Concepts look pre-populated | Summary may be a pure projection of the sealed snapshot. Hidden mutation or unsealed early action enablement is forbidden. |
| Selection | First pointer press selects; second confirms an enabled selected action | Cards imply one-tap actions | Retain select-then-confirm for mutations. One-tap may be considered only for read-only rows and must still call controller confirmation. |
| Staleness | A changed snapshot cancels that confirmation and refreshes selection by `action_id` | Preview/hold could appear current after drift | Invalidate preview and hold immediately on snapshot fingerprint drift; confirm-time re-resolution remains mandatory. |
| Disabled rows | Selectable for explanation, non-executable | Concepts use lock badges | Render only provider-localized reasons; a lock badge cannot alter enablement. |
| Central world aperture | Existing panel mostly owns one side; outside press closes | Dual panes expose a large center | The aperture remains under modal ownership. Its explicit policy may be “outside closes,” but it must never move, tool, attack, or retarget. |
| Portrait world window | Current terminal covers most height | Concept retains upper world | Retain context visually while suppressing movement, Tool, Smash, camera drag/zoom, and virtual controls. |
| Safe area | Current presenter uses a fixed logical inset and portrait clearance | Notches, home indicators, browser bars, UI scaling | Intersect runtime platform safe area with conservative margins; Web shell must honor CSS safe-area insets; all controls remain reachable. |
| Responsive density | Current compact mode activates on mobile, portrait, narrow width, or short height | Concepts are dense high-resolution mock-ups | Breakpoint-specific compositions are required. Do not scale desktop density directly to phones or short landscape. |
| Localization | Exact `en`/`zh-CN` parity and CJK font | Richer descriptions and chips increase wrapping | No concatenated translation fragments. Test wrapping, focus, scrolling, and containment in Chinese at all UI scales. |
| Accessibility | 44 px controls and keyboard/controller focus already exist | Icons, color coding, hold, animation | Preserve text/glyph redundancy, accessible names, focus trap/restore, reduced motion, and cancelable hold feedback. |
| Web | Threadless GL Compatibility and explicit export pack | Large translucency, raster UI, live connectors, POIs | Use pooled Controls and primitive drawing; cap all queries; redraw only on dirty signals; explicitly include every new resource. |

## 6. Responsive adaptation boundary

The concepts should produce three related layouts rather than one scaled screenshot.

| Mode | Qualification | Faithful hierarchy | Required fallback behavior |
|---|---|---|---|
| Wide landscape dossier | Safe area can hold two bounded panels and at least a 280 px central aperture; nominally ≥1180×650 before UI-scale adjustments | Left target dossier; central sealed target/ring; right inspection/preview/nearby context | If aperture or 44 px controls cannot be preserved, collapse to single-side landscape. |
| Compact landscape/desktop | Landscape but dual-pane constraints fail, including 844×390 and high UI scale | One side panel with Summary/Actions and bounded result/preview sections | Connector may be hidden; POIs move inside the modal; scrolling remains bounded. |
| Portrait sheet | Portrait or mobile layout with safe bottom anchoring | Target header, Summary/Actions/History navigation, bounded content, Close/Back/Activate footer, retained upper world | At narrow widths use one tab at a time; at wider portrait widths allow a 40/60 Summary/Actions split. History is backed by a real bounded session log or is unavailable. |

## 7. Scope boundary and acceptance criteria

This recreation includes the dossier shells, target linkage, truthful projections, action-card presentation, bounded previews, validated toasts, optional authority-backed session history, nearby-interest indexing, safe-area handling, and integration with existing HUD/modal/localization/export systems. It does **not** include a wholesale world-art replacement, a new hydrography simulation, generic waypoint persistence, a new irrigation-machine domain, fault diagnostics, power topology, blueprint progression, or maintenance simulation unless those are separately approved and implemented as gameplay authorities.

Acceptance requires all of the following:

| Acceptance dimension | Required outcome |
|---|---|
| Truth | Woodland Grass displays its real surface/biome/walkable/tillable/blocked state; pond displays water class/walkability/irrigation relevance plus only provider-emitted fishing options; greenhouse displays only explicit facility facts and exact option costs. Unsupported concept facts are absent. |
| Authority | Every visible action is a current canonical option. Every activation reaches `confirm_menu()` and no presenter calls a mutation service. |
| Freshness/exact once | A stale preview or hold cancels; stale confirmation performs zero mutation; duplicate cross-input completion commits at most once. |
| Spatial linkage | Overlay binds to the sealed target identity/cell, never re-resolves a replacement, ignores input, and redraws only when dirty. |
| Nearby context | Queries use a bounded index, stable sorting, capped tile-distance rows, and no per-frame node scan. |
| Modal coexistence | Visible world remains non-playable; movement, tools, attacks, zoom, camera gestures, and conflicting touch regions remain suppressed; HUD yields without losing canonical state. |
| Responsive/accessibility | Certified viewports, handedness, UI scales, CJK wrapping, 44 px targets, focus ownership, screen-reader labels, and reduced-motion behavior pass. |
| Performance/Web | Fixed pools, unchanged-state build skips, no idle redraw/query, thread-free export, explicit resource inclusion, and measured budgets pass. |
| Art | Concepts are not runtime textures. Every new raster game/UI asset is generated with GPT Image 2, optimized offline, hashed, and documented in a `SOURCES.md` manifest. |

## 8. Conclusion

The concepts’ **composition, palette, hierarchy, responsive posture, spatial linkage, and card language** are appropriate targets. Their game-state claims are not. The canonical repository is already structured to support a safe recreation if the new UI remains downstream of sealed snapshots, closed operation descriptors, validated results, and explicit indexes/services. The implementation should make the interface look richer while remaining deliberately silent wherever the game lacks authoritative truth.

## Repository references

[1]: ../../scripts/interaction_menu_snapshot.gd "Exact canonical menu snapshot and digest"
[2]: ../../scripts/interaction_option.gd "Exact canonical option contract"
[3]: ../../scripts/interaction_operation_catalog.gd "Read/UI/mutation routes, staleness, domains, and receipts"
[4]: ../../scripts/harvest_interaction_controller.gd "Sealed target, stale refresh, selection, confirmation, and execution gate"
[5]: ../../scripts/interaction_execution_result.gd "Exact result and bounded typed view grammar"
[6]: ../../scripts/harvest_interaction_presenter.gd "Pooled responsive presenter, localization, focus, and debounce"
[7]: ../../scripts/harvest_map_bridge.gd "Runtime composition, movement stop, and HUD modal yielding"
[8]: ../../scripts/mobile_controls.gd "Mobile modal suppression and touch exclusion"
[9]: ../../scripts/world_objects.gd "Visible-cell batched object drawing and redraw counter"
[10]: ../../scripts/field_hud.gd "HUD state/layout skips and modal radar yield"
[11]: ../../export_presets.cfg "Thread-free GL Compatibility Web export and explicit resources"
[12]: ../../data/locales/en.json "English catalog paired exactly with zh-CN.json"
