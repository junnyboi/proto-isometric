# Biome Enemy Movement and Attack SFX Matrix

**Author:** Manus AI
**Scope:** Four biome-specific tiny mobs and the Lava Fields Kilnheart Colossus

## Sound direction

The enemy layer should communicate material and biome before volume. Tiny-mob movement cues are short, low-priority spatial one-shots emitted at a bounded cadence only while locomoting. Tiny-mob attack cues fire once when a warning commits, so the player receives useful audio anticipation without duplicating damage-frame feedback. The boss movement cue is heavier and slower; each of its three attacks receives a unique warning cue because their counterplay differs.

All cues are generated as audio-bearing short carrier videos with **no dialogue, no music, and no ambient bed**, then extracted to mono 48 kHz PCM WAV. Silence is trimmed, a short fade is applied to both ends, peak amplitude is normalized conservatively, and the final files remain compact one-shots. Carrier-video visuals are disposable references and are not shipped.

| Enemy | Cue | Runtime file | Target character | Final target length | Runtime trigger |
|---|---|---|---|---:|---|
| Glassback Scarab | Movement | `mob_glassback_move.wav` | Dry chitin taps, sand grains, faint glassy shell tick | 0.75 s | Bounded locomotion cadence while advancing |
| Glassback Scarab | Attack | `mob_glassback_attack.wav` | Sharp mandible snap with a small sandstone/glass ping | 0.60 s | Entry into committed warning |
| Mire Tick | Movement | `mob_mire_tick_move.wav` | Wet sticky foot plops, reed-fiber brush, soft mud suction | 0.80 s | Bounded locomotion cadence while advancing |
| Mire Tick | Attack | `mob_mire_tick_attack.wav` | Needle-like chitin click followed by a compact mud pop | 0.65 s | Entry into committed warning |
| Rime Shardling | Movement | `mob_rime_shardling_move.wav` | Brittle ice skitters and tiny crystal taps | 0.80 s | Bounded locomotion cadence while advancing |
| Rime Shardling | Attack | `mob_rime_shardling_attack.wav` | Rising crystalline chirp ending in a close ice crack | 0.70 s | Entry into committed warning |
| Ember Skitter | Movement | `mob_ember_skitter_move.wav` | Coal scratches, dry shell clicks, restrained ember hiss | 0.80 s | Bounded locomotion cadence while advancing |
| Ember Skitter | Attack | `mob_ember_skitter_attack.wav` | Compact furnace bite, metal snap, short cinder spit | 0.70 s | Entry into committed warning |
| Kilnheart Colossus | Movement | `boss_kilnheart_move.wav` | Massive basalt footfall, plate groan, low furnace thrum | 1.25 s | Bounded cadence during surface locomotion |
| Kilnheart Colossus | Forge Sweep | `boss_kilnheart_forge_sweep.wav` | Furnace inhale, widening flame arc, heavy vent slam | 1.30 s | Forge Sweep warning commit |
| Kilnheart Colossus | Magma Ram | `boss_kilnheart_magma_ram.wav` | Grinding basalt acceleration and compressed molten roar | 1.35 s | Magma Ram warning commit |
| Kilnheart Colossus | Caldera Barrage | `boss_kilnheart_caldera_barrage.wav` | Three ascending pressure knocks ending in a volcanic crack | 1.50 s | Caldera Barrage warning commit |

## Runtime policy

All twelve cues use the `Enemy` SFX bus. Tiny movement cues have priority zero, a maximum distance of 720 px, and deterministic ±3% pitch variation keyed by entity ID. Tiny attack cues use priority two and 1,100 px. Boss movement uses priority one at 1,500 px. Boss warning cues use priority three at 2,200 px. A staggered per-entity movement cadence and the global bounded spatial voice pool prevent swarms from producing an unreadable wall of repeated sound.

The audio controller records request categories, the last cue path, kind, position, played count, muted count, duplicate suppression, history size, and voice capacity so headless tests can prove the correct mapping without requiring an output device. SFX preferences remain authoritative, and no cue may bypass `AudioService`.

## Carrier generation contract

Each carrier is three seconds, landscape 720p, static camera, and uses a simple enemy-focused visual reference only to guide material and scale. The sound prompt names exactly one foreground effect sequence and explicitly forbids dialogue, voices, music, melody, ambience, wind, crowds, and unrelated impacts. After extraction, the shipped WAV is cut to the target window above rather than retaining the full carrier duration.
