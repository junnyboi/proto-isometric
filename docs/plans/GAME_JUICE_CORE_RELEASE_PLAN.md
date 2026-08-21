# Walker’s Wake — Core Game Juice Release Plan

**Goal:** Make movement, Impact Charge, Smash, destruction, pickups, and relay completion feel immediate, weighty, and semantically distinct without changing gameplay authority.

**Affected area:** Semantic feedback routing, pooled sprite transients, short Web-safe SFX, optional haptics, bounded camera impulses, biome surface tinting, reward/objective dispatch, accessibility transforms, regression coverage, Web export, and public deployment.

**Done condition:** The five GPT Image 2 runtime assets are selected by authoritative semantic events; cosmetic work is prewarmed, capped, priority-aware, and culled within one second; gameplay truth and persistence are unchanged; every phase passes its focused regression gate and the final clean release passes full verification, exported-PCK boot, WebDev deployment, and public-browser smoke.

## Architecture

Gameplay owners continue to commit movement, damage, breaks, charge, inventory, relay progress, and saves. The field-owned `FeedbackRouter` accepts immutable events only after those outcomes resolve. It fans each accepted event into data-driven profiles, bounded camera impulses, a six-voice audio pool, optional finite haptics, target reactions, the existing 128-record particle pool, and a new 16-record sprite-transient pool.

The sprite pool never allocates during play. When saturated, it reclaims only an equal-or-lower-priority entry; frequent footsteps and pickups therefore cannot evict relay completion or a high-value contact. All new sprites use localized monotonic fades. Reduced Flash lowers their alpha and removes scale overshoot. No new effect writes health, velocity, collision, charge, currency, objectives, or save data.

## Executed phases

| Phase | Goal | Affected area | Done condition | Status |
|---|---|---|---|---|
| **G0 — Asset foundation** | Produce the required runtime visual grammar. | Five GPT Image 2 VFX derivatives, three generated WAV cues, source notes, visual catalog, explicit Web export filters. | Clean alpha, practical dimensions, transparent/tintable runtime textures, short mono PCM audio, no generation masters in Git, all assets imported and required by release validation. | **Complete** |
| **G1 — Authoritative Smash** | Give confirmed contact one dominant focal response while preserving miss truth. | Canonical semantic Smash router, generated contact sprite, bounded particles, camera, audio, haptics, actor reactions, accessibility. | Whiffs emit no contact-only visual; accepted hit/break/defeat events emit one pooled contact transient; a 500-event stress case remains within fixed pools; transients recover cleanly. | **Complete** |
| **G2 — Locomotion and charge** | Give Walker traversal industrial mass and make 40%/80% charge crossings noticeable. | Visible-frame gait contacts, start/stop/reversal/block cues, biome surface mapping, generated footstep mask, charge glyph, bounded SFX/haptics. | Movement vectors, speed caps, collision, buffering, and charge math remain unchanged; gait contacts align with visible frames; detents fire exactly once per upward crossing; all eight directions and four surfaces pass. | **Complete** |
| **G3 — Rewards and objectives** | Give routine pickups compact punctuation and relay completion major local celebration. | Pickup and relay profiles, generated spark/flare, generated earcons, priority-aware pool reclamation, post-authority map dispatch. | Pickup feedback has no shake and scales by amount; relay feedback uses the major tier; pickup floods cannot evict relay feedback; frequent effects cull first and every new sprite is gone within one second. | **Complete** |
| **G4 — Release** | Publish the exact verified source superset. | Project version, clean import, full tests, no-threads Web export, PCK boot, WebDev bundle pointers, checkpoint, public smoke, GitHub push. | `./verify.sh` and `./verify.sh --release` pass; source and WebDev host use one exact JS/WASM/PCK set; public build reports the expected ID, reaches field readiness, and logs no blocking runtime error. | **Complete** |
| **G5 — Player VFX intensity** | Let players tune cosmetic feedback density live from 0–100%. | Atomic preferences, bilingual settings slider, pooled particle/sprite density, HUD pulse amplitude, biome-atmosphere marks, telemetry, migration, and focused contracts. | Ten-step slider persists and applies live; 50% halves scalable densities; 0% clears/suppresses cosmetics; critical telegraphs and gameplay truth remain intact; fixed pools never grow. | **Complete** |

## Semantic presentation matrix

| Event | Tier | Generated visual | Audio | Camera/haptic policy | Lifetime |
|---|---:|---|---|---|---:|
| Walk contact | Micro | Biome-tinted `footstep_dust.png` | Sparse surface step | No shake; no haptic | 0.32 s |
| Run contact | Micro | Larger biome-tinted `footstep_dust.png` | Heavy gait | No shake; no haptic | 0.38 s |
| 40% charge | Micro | `charge_ready.png` | Charge detent | Small bounded cue | 0.46 s |
| 80% charge | Major-ready | Larger `charge_ready.png` | Charge detent | Bounded cue; exactly once | 0.58 s |
| Confirmed Smash/break | Standard | `impact_contact.png` | Outcome/material role | Profile-bounded camera and optional haptic | 0.26–0.38 s |
| Fauna defeat | Major contact | Larger `impact_contact.png` | Defeat role | Profile-bounded camera and optional haptic | 0.48 s |
| Scrap/Core pickup | Micro/standard | `pickup_spark.png` scaled by amount | Pickup earcon | No shake; short optional haptic | 0.48 s |
| Relay complete | Major | `relay_flare.png` | Relay completion phrase | 0.22 s camera envelope; finite optional haptic | 0.90 s |

## Regression gates

Each playable phase runs focused `gdlint`, clean Godot import, executable smoke contracts, and `git diff --check`. Phase completion then runs the full `./verify.sh` project gate. The final release additionally runs `./verify.sh --release`, which performs another clean import, complete test run, no-threads Web export, and exported-PCK boot.

The new focused contracts verify asset selection, surface tinting, profile hierarchy, exactly-once semantic dispatch, six-voice audio reuse, 128-particle preservation, 16-burst prewarming, low-priority reclamation, major-relay protection, sub-one-second cleanup, Reduced Flash behavior, line budgets, and unchanged runtime state ownership.
