# Walker’s Wake — Game Juice Proposal

**Goal:** Make movement, Smash, Impact Charge, destruction, relay completion, and reward collection feel powerful and immediately legible without changing authoritative gameplay, obscuring hazards, or breaking Web/mobile performance.

**Affected area:** Field feedback routing, contact and movement VFX, production SFX, optional haptics, accessibility policy, performance budgets, tests, Web export, and public deployment.

**Done condition:** Every key action presents a synchronized **acknowledgement → authoritative result → persistent consequence**; cosmetic channels remain bounded and independently reducible; the complete regression suite, clean Web export, exported-pack boot, and public-browser smoke pass after each playable phase.

## Executive proposal

Industry evidence and production postmortems converge on one useful definition: **game juice is causal communication with proportional sensory emphasis**. Input acknowledgement should be immediate, but a hit, break, pickup, or relay confirmation must wait for authoritative resolution. The world must visibly answer the action; particles, shake, audio, and haptics are supporting channels rather than gameplay truth.[1][2][3]

Walker’s Wake already has strong foundations: a committed Smash animation with one contact frame, Impact Charge bands, target hit flash, pooled biome debris, camera impulse, resource magnet motion, relay state changes, damage feedback, and accessibility toggles. Its principal gap is not a lack of effects. The gap is that these effects do not yet form a consistent **feedback grammar**. Movement has little ground response, Smash contact lacks a dominant authored focal transient and dry impact identity, charge thresholds are visually quiet, and relay/pickup success is less celebratory than the decisions that produced it.

The proposed release introduces a local, settings-aware `FeedbackDirector` owned by the field scene. Gameplay commits remain in existing authorities. The director receives compact semantic presentation events and maps them to pooled GPT Image 2 sprites, prewarmed audio voices, optional bounded haptics, and one-way flash-safe fades. Existing procedural telegraphs, hit geometry, persistence, damage, currency, and objective state remain untouched.

## Industry principles applied

| Priority | Principle | Walker’s Wake decision |
|---:|---|---|
| **P0** | Immediate truthful acknowledgement protects agency; outcome feedback follows authoritative resolution.[1][4] | Keep direct drive and the existing attack acceptance immediate. Trigger strong contact cues only from the authoritative impact frame and committed break/hit/result. |
| **P0** | Danger, timing, and targeting must outrank decoration.[5][6] | Never cull hazard boundaries, worm telegraphs, objective state, or contact geometry. Drop distant/low-priority garnish first. |
| **P0** | Targets and the world should visibly answer an action.[2][3] | Preserve hit flash, stagger, break mutation, relay state, and committed counters as the primary consequence. VFX are subordinate. |
| **P1** | Congruent visual, audio, and optional haptic cues are stronger than unrelated effect density.[7] | Drive the contact flash, dry SFX, sprite transient, and optional haptic from one event at one position. |
| **P1** | Actions read through anticipation, contact, and bounded recovery.[2][3] | Preserve the existing Smash wind-up/contact/recovery and buffered recovery. Add charge-ready acknowledgement without delaying input. |
| **P2** | Camera motion and hit-stop are selective accents with accessibility risk.[5][8] | Retain existing bounded camera offset and true-zero setting. Do not add camera roll, zoom punches, or global `Engine.time_scale` manipulation in this release. |
| **P2** | Reward celebration should scale with reward significance and preserve control.[9] | Routine scrap/Core collection gets a compact burst and earcon; relay completion gets a larger local flare, persistent HUD/world state, and no modal interruption. |
| **Performance** | Godot Web needs a Compatibility-safe baseline and measured pools.[10][11] | Use sprite/ring baselines, fixed pools, short lifetimes, prewarmed audio players, no runtime particle trails, and no per-event node instantiation. |
| **Accessibility** | Critical meaning must survive any one disabled sensory channel; intentional flashes must remain below the safety floor.[5][6][12] | Use monotonic localized fades, no repeated full-screen luminance reversal, no color-only meaning, SFX toggle compliance, reduced-flash density reduction, and optional haptics only. |

## Current-state analysis

### What already works

The existing Smash flow accepts input, stops Walker translation, scans a fixed footprint, plays an authored directional attack, resolves once at frame 11, consumes charge once, and buffers movement for recovery. `ImpactEffects` already provides bounded camera impulse and a prewarmed 128-dictionary particle pool. Biome destructibles now use material-specific sprites and debris palettes with strict one-second cleanup. Worms visibly flash and stagger, relays preserve completed state, and pickups magnetize toward Walker before committed counters update.

These are excellent truth contracts. The proposed work deliberately builds around them instead of replacing them.

### Highest-value gaps

| Event | Current read | Gap | Proposed response |
|---|---|---|---|
| Drive/run | Animation and camera follow | Little terrain contact or speed punctuation | Distance-driven, terrain-tinted foot dust with a quiet material step voice; no per-frame or idle effect. |
| Charge threshold | HUD meter and amber arcs | Band transitions can be missed during field focus | One localized charge glyph/pulse and short ready earcon when entering band 1 or 2; no repeated loop. |
| Smash accepted | Wind-up animation and status text | Acceptance is readable but visually restrained | Preserve pose; no false hit flash or heavy sound before contact. |
| Smash contact/whiff | Procedural ring, debris when applicable, camera shake | No single authored focal transient or semantic dry sound | GPT Image 2 contact burst; success/whiff tint and pitch; optional short haptic only for authoritative solid contact. |
| Destructible break | Biome debris, mutation, scrap | Strong fragments, weak contact focal point | Contact burst at break position before the existing pooled biome debris tail. |
| Relay complete | World ring and HUD/status update | Major objective is under-celebrated | Larger teal relay flare, ascending resolved SFX, optional bounded haptic, persistent state/HUD unchanged. |
| Core/scrap pickup | Magnet trail and counter | Collection lacks compact acquisition punctuation | Amber/teal pickup spark, concise earcon, aggregated amount scaling, no shake or hit-stop. |

## Feedback grammar

The release uses four semantic tiers.

| Tier | Examples | Presentation policy |
|---|---|---|
| **Micro** | Footstep, low charge threshold | One short local visual or low-priority voice; never shake or vibrate. |
| **Standard** | Smash contact, destructible break, valuable pickup | Local authored transient, dry SFX, existing target/world reaction; optional bounded haptic for physical contact. |
| **Major** | High-charge Smash, relay completion | Larger but localized transient, one prioritized audio phrase, optional bounded haptic; no camera seizure or modal UI. |
| **Critical** | Hazard warning, chassis damage, shutdown | Existing telegraphs and damage systems remain highest priority and are never obscured by the new director. |

## Asset direction

All new static visual assets will be generated with **GPT Image 2**, using the approved 2:1 isometric desert concepts as style references. Source generations use a temporary magenta background and background removal. Runtime derivatives are tightly trimmed transparent PNGs, reduced to practical texture sizes, and validated for a centered pivot and clean alpha.

The five required VFX assets are:

1. `impact_contact.png` — compressed amber/ivory industrial contact star with directional shards;
2. `footstep_dust.png` — low, ground-hugging dust footprint cloud suitable for surface tinting;
3. `charge_ready.png` — compact angular amber energy glyph with a readable ring silhouette;
4. `relay_flare.png` — teal geometric signal flare with radial antenna motifs;
5. `pickup_spark.png` — compact teal-and-amber acquisition spark.

Production SFX follow the project’s audio policy. Mirelo is currently unavailable, so the fallback is an audio-bearing generated carrier followed by deterministic extraction into short runtime WAV derivatives. Only the accepted WAVs and a concise source note enter Git.

## Performance and safety budgets

| Budget | Limit |
|---|---:|
| Pooled sprite records | 32 prewarmed, zero growth |
| Concurrent sprite transients | 32 hard cap; reclaim lowest-priority/oldest cosmetic entry |
| Longest new transient | 0.85 seconds |
| Footstep cadence | Distance-driven and cooldown-limited; no idle emission |
| Audio voices | 6 prewarmed players; priority steal, no runtime player allocation |
| Haptics | Standard/major contacts only, cooldown-limited, optional, silent failure |
| Flash behavior | Localized monotonic fade; no oscillating alpha or full-screen white/red inversion |
| Redraw behavior | No redraw request when no transient is active |
| Gameplay state | No damage, hit geometry, reward, relay, save, or movement mutation in the director |

## Success criteria

The release succeeds when a player can answer, without reading debug telemetry: **Was my input accepted? What did I contact? What changed? Was it a pickup or an objective? Can I move again?** Those answers must remain available with sound disabled, camera shake disabled, reduced flash enabled, or new cosmetic effects saturated and reclaimed.

The technical gate is equally strict: focused lint/tests pass during iteration; after each phase `./verify.sh` passes; a clean `./verify.sh --release` export boots from its PCK; the exact bundle is synchronized to WebDev; and the public browser reports the expected build identity, field readiness, and no startup/runtime errors.

## References

[1]: https://web.cs.wpi.edu/~claypool/papers/precision-deadline/final.pdf "Claypool and Claypool — Latency and player actions"
[2]: https://www.supergiantgames.com/blog/hades-the-high-speed-update-patch-notes/ "Supergiant Games — Hades: The High Speed Update"
[3]: https://news.blizzard.com/en-us/article/23746639/diablo-iv-quarterly-updatedecember-2021 "Blizzard — Diablo IV Quarterly Update"
[4]: https://www.gamedeveloper.com/design/recalling-the-leviathan-axe "Game Developer — Recalling the Leviathan Axe"
[5]: https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/117 "Xbox Accessibility Guideline 117 — Camera and motion"
[6]: https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/103 "Xbox Accessibility Guideline 103 — Additional channels"
[7]: https://pmc.ncbi.nlm.nih.gov/articles/PMC5712580/ "Audiovisual integration and temporal correspondence"
[8]: https://royalsocietypublishing.org/rsos/article/13/3/251930/480852/Influences-of-visual-effects-on-sense-of-agency-in "Visual effects and sense of agency"
[9]: https://eprints.qut.edu.au/119100/1/Cody_Phillips_Thesis.pdf "Phillips — Video game rewards"
[10]: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html "Godot — Exporting for Web"
[11]: https://docs.godotengine.org/en/latest/tutorials/performance/general_optimization.html "Godot — General optimization"
[12]: https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html "WCAG 2.2 — Three Flashes or Below Threshold"
