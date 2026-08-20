# Walker’s Wake — Game Juice Implementation Plan

**Author:** Manus AI  
**Engine:** Godot 4.7.1  
**Planning baseline:** Walker’s Wake 1.5.6 at `280bfae`  
**Baseline verification:** 1,318 smoke checks, headless boot, and project verification pass  
**Source proposal:** [Walker’s Wake — Game Juice Analysis and Proposal](../../../../research/game-juice/WALKERS_WAKE_JUICE_PROPOSAL.md)  
**Delivery rule:** Every phase is a playable release. Each phase receives focused tests, the canonical release verification command, a fresh no-threads Web export, exact WebDev bundle attachment, public browser smoke, a WebDev checkpoint, a Git commit, and a GitHub push before the next phase begins.

## Implementation decisions

The implementation preserves the existing frame-11 Smash contact, hit footprint, damage, charge economy, AI, rewards, save schema, movement buffering, dossier transitions, and bounded pooled debris. Gameplay remains authoritative in its current owners. New juice systems consume immutable outcomes and may not mutate health, currency, objectives, collision, inventory, or saves.

The architecture uses a small semantic event vocabulary instead of letting every owner choose arbitrary effects. **Action**, **material**, **outcome**, and **strength** remain orthogonal so a heavy Smash against wet wood can combine one heavy-action profile, one wet-wood profile, and one break outcome without requiring a bespoke effect stack.

Routine contact emphasis uses local presentation holds rather than global `Engine.time_scale`. Camera, haptics, particles, audio, and UI motion all support true-zero or reduced modes. Misses never receive contact-only presentation. Critical gameplay meaning remains readable with shake, haptics, audio, particles, and flashes independently disabled.

## Phase summary

| Phase | Release target | Playable increment | Canonical regression gate |
|---|---:|---|---|
| **J0** | 1.5.6 | Latest source synchronized and verified before juice changes | `./verify.sh` |
| **J1** | 1.6.0 | Semantic Smash feedback and outcome hierarchy | Focused feedback contracts + `./verify.sh --release` + live Smash smoke |
| **J2** | 1.6.1 | Walker locomotion weight and charge detents | Focused locomotion/charge contracts + full release gate + live traversal smoke |
| **J3** | 1.6.2 | Complete material and fauna reaction grammar | Material/fauna matrix contracts + full release gate + live multi-biome smoke |
| **J4** | 1.6.3 | Reward, relay, Refit, and terminal staging | HUD/UI/localization contracts + full release gate + live objective flow smoke |
| **J5** | 1.6.4 | Restrained biome soundscapes and environmental response | Audio priority/density contracts + full release gate + live browser audio smoke |
| **J6** | 1.6.5 | Quality tiers, graded comfort controls, and stress certification | Preference migration, parity, stress, release, and cross-setting live smoke |

## J0 — Verified implementation baseline

**Goal:** Establish runtime truth on the latest upstream source before any feedback work begins.

**Affected area:** Git synchronization; recent movement buffering in `scripts/drive_input_buffer.gd`; dossier transitions in `scripts/character_hover_card.gd`; pooled biome debris in `scripts/impact_effects.gd`; canonical test and export behavior in `verify.sh`.

**Done condition:** Local `main` equals upstream `280bfae`, the tree is clean, project version is 1.5.6, `./verify.sh` passes 1,318 smoke checks and headless boot, and the current WebDev host remains unchanged until J1 has a verified replacement bundle.

## J1 — Semantic Smash feedback and impact hierarchy

**Goal:** Make miss, fauna hit, heavy fauna hit, fauna defeat, desert-rock break, and one generated-biome prop break perceptually distinct while preserving the authoritative Smash result and frame-11 contact.

**Affected area:**

| Path | Planned change |
|---|---|
| `scripts/feedback_event.gd` | Add a validated immutable dictionary builder with event ID, sequence ID, position, direction, outcome, strength, material, priority, deterministic seed, timestamp, and target metadata. |
| `scripts/feedback_profiles.gd` | Add data-driven light, standard, heavy, defeat, and break presentation profiles with local hold, camera envelope, particle tier, audio roles, and haptic envelope. |
| `scripts/feedback_router.gd` | Add the presentation-only dispatcher, deduplication, sequence counters, burst aggregation, accessibility snapshot, channel instrumentation, and test inspection API. |
| `scripts/feedback_audio.gd` | Add bounded Web-safe `AudioStreamPlayer` pools for swing, contact, weight, material, and outcome roles with priority, no immediate repeat, and explicit voice caps. |
| `scripts/haptic_router.gd` | Add capability-checked finite gamepad/handheld pulses, explicit stop/reset behavior, cooldowns, and true-zero enforcement. |
| `scripts/impact_targeting.gd` | Extend the existing result dictionary with per-target pre/post health, kind, position, defeated state, and stable IDs without changing damage application. |
| `scripts/walker_avatar.gd` | Add a local contact-pose hold and a small presentation-only recoil/settle API; keep attack duration, impact frame, buffered movement release, and animation authority unchanged. |
| `scripts/sandworms.gd` | Add presentation-only directional reaction fields and APIs for surviving fauna; defeated fauna keep their existing authoritative state and reward timing. |
| `scripts/impact_effects.gd` | Replace single overwrite shake with capped mixed impulses; add compact directional contact bursts and quality-aware counts while retaining the 128-entry pool. |
| `scripts/isometric_map.gd` | Construct and bind the router, build semantic events only after `ImpactTargeting` and rock mutation resolve, and replace direct hit-only presentation calls. The file remains at or below 1,000 lines. |
| `scripts/performance_sampler.gd` | Add feedback dispatch, cull, audio voice, haptic request, camera impulse, event latency, and active presentation gauges. |
| `assets/audio/` | Add accepted runtime derivatives for swing, contact, heavy body, stone break, wet-wood break, and defeat. Generate through the approved project SFX route; retain only runtime WAV files and a concise source note. |
| `test/test_feedback_router.gd` | Add event validation, one-truth dispatch, miss suppression, profile selection, deduplication, camera cap, audio/haptic gating, and telemetry contracts. |
| `test/test_attack_aoe.gd`, `test/test_performance.gd`, `test/smoke.gd` | Preserve footprint/one-contact behavior and add live assertions for semantic feedback ownership, exactly-once dispatch, bounded pool use, and clean recovery. |
| `test/test_contracts.gd`, `export_presets.cfg`, `project.godot` | Register the new tests and shipping resources; advance the release to 1.6.0. |

**Done condition:** Five hundred deterministic impact cases produce zero false contact-only events on misses and exactly one semantic event per accepted contact result. Every damaging hit has a target reaction plus one non-camera confirmation. Frame-11 contact time, footprint, damage, charge consumption, rewards, movement buffering, and save behavior remain unchanged. Camera impulses aggregate under a hard cap and return exactly to zero. Haptic Off emits no requests. Muted SFX changes no gameplay. Focused feedback, attack, accessibility, and performance contracts pass; `gdlint` passes; `scripts/isometric_map.gd` and `test/smoke.gd` remain at or below 1,000 lines; EN/zh-CN catalogs remain identical if copy is added; `./verify.sh --release` passes; the exact clean bundle boots from its exported PCK, is deployed to WebDev, and live public smoke confirms miss, contact, break, and recovery. The phase receives a checkpoint, commit, and GitHub push before J2 begins.

## J2 — Walker locomotion weight and charge detents

**Goal:** Make ordinary driving, running, reversal, blocking, stopping, and Impact Charge thresholds feel like controlled industrial mass without changing movement responsiveness or terrain physics.

**Affected area:**

| Path | Planned change |
|---|---|
| `scripts/walker_avatar.gd` | Emit deterministic gait-contact events from visible walk frames; add bounded chassis bob/settle and start/stop presentation that never changes world position. |
| `scripts/walker_locomotion_feedback.gd` | Add gait phase, start/stop/reversal/blocked event classification, surface selection, cooldowns, and low-priority semantic dispatch through the J1 router. |
| `scripts/feedback_profiles.gd` | Add movement-start, walk-contact, run-contact, reversal, blocked, stop, and charge-threshold profiles below threat and combat priority. |
| `scripts/impact_effects.gd` | Add small pooled surface wakes for sand, wetland, snow/ice, and volcanic terrain with zero camera impulse by default. |
| `scripts/feedback_audio.gd`, `assets/audio/` | Add accepted servo engage/release, heavy gait, surface step, and charge-detent runtime cues with sparse cooldowns and no-repeat selection. |
| `scripts/impact_charge.gd` | Emit exactly-once band-crossing signals at 40% and 80%; no continuous vibration and no charge-math change. |
| `scripts/isometric_map.gd` | Bind locomotion and charge sources to the router and report blocked transitions without adding movement authority. Maintain the 1,000-line cap through extracted modules. |
| `test/test_walker_locomotion_feedback.gd` | Add visible-frame gait alignment, start/stop/reversal classification, blocked response, surface-family selection, cooldown, and true-zero contracts. |
| `test/test_field_ui.gd`, `test/test_performance.gd`, `test/smoke.gd` | Preserve drive acceleration, coasting, ice, mud, run multiplier, recovery buffer, charge math, pool bounds, and live field behavior. |
| `test/test_contracts.gd`, `export_presets.cfg`, `project.godot` | Register the new module/tests/assets and advance the release to 1.6.1. |

**Done condition:** Visible gait contacts and emitted step events agree across all eight directions. Start, stop, reversal, run threshold, blocked movement, and surface transitions produce distinct bounded feedback without altering velocity, cell transitions, input buffering, collision, or Impact Charge gain/decay. Traversal cues never steal threat or contact audio voices. Charge detents emit once per upward crossing and reset correctly after consumption. Focused locomotion, surface-drive, charge, input-buffer, performance, and smoke contracts pass; `./verify.sh --release` passes; the exact Web bundle is deployed and public smoke confirms traversal, run threshold, block, Smash recovery, and camera stability. The phase receives a checkpoint, commit, and GitHub push before J3 begins.

## J3 — Complete material and fauna reaction grammar

**Goal:** Give every shipped destructible and fauna archetype a reusable visual, audio, directional, and state-appropriate response vocabulary.

**Affected area:**

| Path | Planned change |
|---|---|
| `scripts/biome_destructibles.gd` | Add stable material-family IDs for dry stone, wet wood/foliage, frozen stone, frozen wood, basalt, and obsidian while preserving current kind and palette APIs. |
| `scripts/fauna_feedback_catalog.gd` | Add species-family response tags, flash palette, reaction scale, armor/poise substitute, and audio material mapping for Sandworm, Mud Skimmer, Rime Stalker, and Cinder Crawler. |
| `scripts/sandworms.gd` | Render presentation recoil/compression/flash from the catalog; uninterruptible states receive an additive micro-response without changing AI state. |
| `scripts/impact_effects.gd` | Add material-specific directional debris shapes, gravity, lifetime, opacity, and persistent compact contact accents within the existing pool. |
| `scripts/feedback_audio.gd`, `assets/audio/` | Add accepted frozen stone/wood, basalt, obsidian, shell/body, and armor-contact cues using orthogonal action/material/outcome layers. |
| `scripts/feedback_profiles.gd`, `scripts/feedback_router.gd` | Resolve all current material/species families, aggregate multi-target and multi-prop feedback, and cull tails/debris before semantic transients. |
| `data/locales/en.json`, `data/locales/zh-CN.json` | Add only semantic material/outcome captions required by UI, with exact key and named-placeholder parity. |
| `test/test_material_feedback.gd` | Add complete kind-to-material, fauna-to-family, reaction-direction, flash-reset, aggregation, locale, and pool-budget contracts. |
| `test/test_biome_destructibles.gd`, `test/test_biome_fauna.gd`, `test/test_performance.gd`, `test/smoke.gd` | Preserve generation, damage, rewards, AI transitions, pooled fragments, Web bounds, and live multi-target Smash behavior. |
| `test/test_contracts.gd`, `export_presets.cfg`, `project.godot`, `assets/fonts/NotoSansCJKsc-ProtoIsometric.otf` | Register shipping resources, refresh CJK glyph coverage if copy changes, and advance the release to 1.6.2. |

**Done condition:** All seven destructible kinds map deterministically to six broad material families; all four fauna kinds map to a species response profile. Directional reaction points away from the incoming Smash. Surviving uninterruptible fauna visibly acknowledge valid damage without leaving their authoritative state. Multi-target and multi-prop results emit one aggregate camera/haptic packet with per-target visual reactions and bounded audio layers. Material-specific effects remain below the global pool and voice caps. EN/zh-CN key and placeholder parity passes. Focused material, biome, fauna, combat, localization, performance, and smoke contracts pass; `./verify.sh --release` passes; the exact bundle is deployed and live smoke covers at least two biomes plus one fauna family. The phase receives a checkpoint, commit, and GitHub push before J4 begins.

## J4 — Reward, objective, Refit, and terminal staging

**Goal:** Give charge thresholds, salvage deltas, relay completion, repair, Refit installation, extraction, failure, and next-run deployment a clear attention hierarchy without delaying authoritative state.

**Affected area:**

| Path | Planned change |
|---|---|
| `scripts/ui_feedback_animator.gd` | Add reusable interruptible scale/color/opacity pulses with Reduced Motion fallbacks, one owner per property, and instrumentation. |
| `scripts/field_hud.gd` | Compare sealed state snapshots to pulse charge thresholds, scrap/Core deltas, chassis loss, and relay completion; values remain authoritative and immediate. |
| `scripts/outpost_interface.gd` | Stage repair and module-install confirmation after state change; never animate or deduct currency before authoritative success. |
| `scripts/relay_registry.gd` | Replace generic pitched UI reuse with semantic relay progress/completion events and one aggregate completion accent. |
| `scripts/run_terminal_flow.gd` | Add success/failure reveal choreography, banked/lost resource emphasis, modifier selection confirmation, and launch transition; focus and mobile control behavior remain unchanged. |
| `scripts/feedback_profiles.gd`, `scripts/feedback_audio.gd`, `assets/audio/` | Add charge, pickup, relay, repair, install, extraction, failure, and deploy cues with UI/combat priority separation. |
| `scripts/accessibility_panel.gd` | Apply current Reduced Flash/motion behavior to the animator and terminal without introducing new settings until J6. |
| `data/locales/en.json`, `data/locales/zh-CN.json` | Add semantic captions only where needed, with complete parity and no concatenated translated fragments. |
| `test/test_ui_feedback.gd` | Add immediate-authority, interruptible-replay, rapid-pickup aggregation, relay exactly-once, repair/Refit success-only, terminal focus, reduced-motion, and locale-switch contracts. |
| `test/test_field_ui.gd`, `test/test_refit.gd`, `test/test_terminal_flow.gd`, `test/test_localization.gd`, `test/smoke.gd` | Preserve HUD diffing, wallets, module installation, settlement, modifier selection, responsive layout, and bilingual runtime refresh. |
| `test/test_contracts.gd`, `export_presets.cfg`, `project.godot`, font subset if required | Register the module/tests/assets and advance the release to 1.6.3. |

**Done condition:** State values change immediately and presentation proxies animate afterward. Rapid pickups aggregate rather than restart an unbounded effect. Relay completion and Refit installation dispatch exactly once. Extraction is the only screen-scale celebration. Failure remains concise and retry-ready. Reduced Motion replaces overshoot/travel with a short fade or immediate state. EN, zh-CN, pseudolocalization, narrow layout, and existing UI-scale contracts pass with no clipped controls or lost focus. Focused HUD, relay, Refit, terminal, localization, responsive, accessibility, and performance tests pass; `./verify.sh --release` passes; the exact bundle is deployed and live smoke covers pickup, relay or outpost, terminal reveal, language switching, and retry/deploy. The phase receives a checkpoint, commit, and GitHub push before J5 begins.

## J5 — Restrained biome soundscapes and environmental response

**Goal:** Give desert, wetland, frozen, and lava traversal a restrained sonic and tactile identity while preserving player-contact and threat priority.

**Affected area:**

| Path | Planned change |
|---|---|
| `scripts/biome_soundscape.gd` | Add biome bed selection, deterministic sparse one-shot scheduling, distance/priority rules, user-gesture readiness, focus/pause recovery, and crossfade through direct gain automation. |
| `scripts/feedback_audio.gd` | Add stable buses/groups for Combat, Threat, Foley, Fauna, Ambience, and UI with explicit voice caps and cull order. |
| `scripts/walker_locomotion_feedback.gd` | Route surface identity and running intensity to soundscape/foley without increasing step density under frame spikes. |
| `scripts/desert_atmosphere.gd`, biome runtime owners | Add low-cost environment response parameters such as running wake intensity and storm-pressure accents; gameplay and hazards remain unchanged. |
| `assets/audio/` | Add accepted loopable mono runtime derivatives for desert wind, wetland air/water, frozen wind, and lava rumble plus sparse fauna/environment one-shots. Use the approved generated-audio fallback if Mirelo is unavailable, downmix/resample for Web, delete generation masters, and record a concise source note. |
| `test/test_biome_soundscape.gd` | Add deterministic scheduling, concurrency, cull priority, biome transition, mute, focus recovery, and no-semantic-audio-dependency contracts. |
| `test/test_performance.gd`, `test/test_localization.gd`, `test/smoke.gd` | Preserve Web voice/memory bounds, runtime language, field readiness, and threat presentation. |
| `test/test_contracts.gd`, `export_presets.cfg`, `project.godot` | Register the soundscape, audio assets, and tests; advance the release to 1.6.4. |

**Done condition:** Every biome selects a distinct restrained bed and surface family; common ambience obeys deterministic cooldown and concurrency caps; threat and confirmed-player-contact voices are never culled by ambience. Muting SFX removes all gameplay SFX and ambience but no unique gameplay information. Browser audio begins only after a valid user gesture or existing unlocked context, recovers after tab focus changes, and produces no errors when unavailable. Runtime audio remains short pre-rendered Web-safe WAV content with bounded bundle growth. Focused audio, biome, locomotion, accessibility, performance, exported-PCK, and smoke contracts pass; `./verify.sh --release` passes; the exact bundle is deployed and live public smoke confirms audio unlock, biome transition, threat/contact priority, mute behavior, and stable field readiness. The phase receives a checkpoint, commit, and GitHub push before J6 begins.

## J6 — Quality tiers, graded comfort controls, and stress certification

**Goal:** Make the complete juice stack scalable from true-zero/minimal feedback to full presentation while preserving combat semantics, bilingual UI, saved preferences, and Web performance.

**Affected area:**

| Path | Planned change |
|---|---|
| `scripts/player_preferences.gd` | Add backward-compatible shake intensity, hit-stop intensity, haptic intensity, SFX volume, and effects quality values while accepting existing 1.5.x boolean snapshots. |
| `scripts/accessibility_panel.gd` | Replace binary feedback controls with compact cycles or percentages, add effects quality and hit-stop controls, maintain EN/zh-CN live refresh, and fit desktop/mobile layouts. |
| `scripts/feedback_router.gd` | Apply global quality, motion, flash, haptic, and audio transforms; enforce true zero; merge event bursts; and protect critical semantics. |
| `scripts/impact_effects.gd` | Add Full/Reduced/Minimal particle and debris budgets by changing actual spawn counts/lifetimes, not only opacity. |
| `scripts/feedback_audio.gd`, `scripts/haptic_router.gd`, `scripts/ui_feedback_animator.gd`, `scripts/biome_soundscape.gd` | Apply graded settings, independent UI/gameplay priorities, explicit finite durations, and focus/scene reset behavior. |
| `scripts/flash_limiter.gd` | Add a conservative global limiter for overlapping full-screen flashes while preserving localized target reactions. |
| `scripts/performance_sampler.gd` | Add per-tier feedback cost, voices, culls, active groups, maximum impulses, and recovery gauges. |
| `test/test_feedback_stress.gd` | Add deterministic maximum-fauna, three-target, six-prop, open-dossier, bilingual-large-UI, Full/Minimal, focus-loss, and ten-minute-equivalent pool/voice stability scenarios. |
| `test/test_preferences.gd`, `test/test_localization.gd`, `test/test_field_ui.gd`, `test/test_performance.gd`, `test/smoke.gd` | Add migration, validation, persistence, true-zero, tier ordering, flash, bilingual fit, and release budget contracts. |
| `data/locales/en.json`, `data/locales/zh-CN.json`, font subset, `test/test_contracts.gd`, `export_presets.cfg`, `project.godot` | Add settings copy with exact parity, refresh glyph coverage, register shipping resources, and advance the release to 1.6.5. |

**Done condition:** Existing 1.5.x preferences load without loss. New values validate, save atomically, and persist. Shake 0 yields exactly zero camera displacement; hit-stop 0 yields no local hold; haptics 0 emits no request; SFX 0 plays no voice; Minimal retains compact contact and critical telegraph semantics while reducing actual particle/debris/audio counts. Full, Reduced, and Minimal are perceptibly ordered and do not change damage, collision, AI, rewards, or saves. The combined flash sequence follows the conservative three-flashes-per-second route. EN/zh-CN keys and placeholders match, settings fit at narrow viewport and maximum supported UI scale, and runtime language changes preserve focus. Stress tests show no unbounded nodes, particles, debris, voices, haptics, or memory; standard Web meets p95 ≤16.67 ms and p99 ≤25 ms on the reference browser where achievable, while the declared low tier meets p95 ≤33.33 ms and p99 ≤45 ms with no warm effect hitch above 50 ms. Focused migration, settings, accessibility, localization, stress, performance, save, and smoke contracts pass; `./verify.sh --release` passes; the exact final bundle is deployed and live smoke covers every tier, true-zero settings, language switching, Smash, traversal, dossier, outpost/terminal, focus recovery, and public boot. The final phase receives a checkpoint, commit, and GitHub push.

## Final release condition

**Goal:** Deliver the complete game-juice implementation as the current canonical Walker’s Wake release.

**Affected area:** Final clean source state, Git history, no-threads Web export, WebDev host pointers and build ID, public deployment, and release metadata.

**Done condition:** GitHub `main` contains the latest verified source superset; the source tree and WebDev host are clean; the public domain serves the exact final JS/WASM/PCK hashes from the final source commit; the public canvas reaches `field-ready`; no blocking browser console error occurs; EN and zh-CN both render; one complete title-to-field-to-objective/terminal flow is stable; and every phase checkpoint remains available for rollback.

## References

[1]: ../../../../research/game-juice/WALKERS_WAKE_JUICE_PROPOSAL.md "Walker’s Wake — Game Juice Analysis and Proposal"
[2]: ../../verify.sh "Canonical project verification and release command"
