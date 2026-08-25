# Biome Weather Audio System — Production Contract

**Author:** Manus AI
**Engine target:** Godot 4.7.2
**Runtime scope:** Desert, Oasis Wetlands, Frozen Tundra, and Lava Fields

## Purpose and mix position

The game already owns one quiet environmental ambience bed per biome and routes that layer through the `Ambient` bus.[1] The new system adds a **separate weather layer** rather than replacing those beds. Its purpose is to communicate airborne conditions—sand, rain, snow, ash, and geothermal pressure—while the existing ambience remains the low environmental floor and the `Enemy` bus remains the source of actionable attack and movement cues.[2]

The shipped ambience assets measure approximately −46 to −51 LUFS integrated and the specialized enemy attacks are roughly twenty decibels more prominent. The weather beds therefore target **−34 LUFS integrated before runtime gain**, preserving a clear hierarchy: enemy cue first, weather second, ambience floor third. Weather uses the existing `Ambient` preference and bus, so the established Ambience slider and true-zero mute remain authoritative.[3]

## Four-biome soundscape matrix

| Biome | Weather identity | Audible materials | Explicit exclusions | Runtime base gain |
|---|---|---|---|---:|
| **Desert** | **Glasswind Front** | Broad dry crosswind, fine sand hiss, occasional granular gust | No thunder, animals, voices, melody, or impact hits | −10.0 dB |
| **Oasis Wetlands** | **Reedrain Veil** | Light rain on reeds and shallow water, soft droplets, distant damp breeze | No frogs, birds, thunder, music, or sharp splashes | −11.0 dB |
| **Frozen Tundra** | **Whiteout Drift** | Airy blizzard wash, fine ice-crystal skitter, restrained snow gust | No tonal drone, howls, cracking attack cues, voices, or music | −10.5 dB |
| **Lava Fields** | **Ashfall Breath** | Ash-laden wind, low geothermal rumble, sparse ember crackle | No explosions, boss roars, rhythmic pulses, voices, or music | −12.0 dB |

Each bed is a mono 48 kHz, 16-bit PCM WAV with an exact **8.0-second loop**. Mono matches the current ambience architecture and avoids implying a world-space direction for global weather. The carrier generation remains disposable; only the extracted and seam-corrected WAVs ship.

## Loop preparation contract

Each source carrier is generated at ten seconds with static visual reference, no dialogue, no music, and exactly one continuous atmospheric texture. Extraction takes a stable interior eight-second section, applies conservative loudness normalization, and makes the loop seam through a two-second equal-power tail-to-head overlap. The output is validated for exact duration, channel count, sample rate, distinct content hash, nonzero energy, bounded true peak, and low seam discontinuity.

> A weather loop is accepted only when the first and last analysis windows have compatible RMS energy and the seam click metric remains below the project’s automated threshold.

## Runtime architecture

A new `biome_weather_audio.gd` node owns two prewarmed `AudioStreamPlayer` voices. It performs constant-power crossfades over **2.4 seconds**, assigns all players to the `Ambient` bus, configures forward looping on WAV streams, and restarts any unexpectedly stopped audible voice. At most two weather voices exist, including during biome transitions.

`feedback_router.gd` creates the weather node next to music and the existing biome soundscape. The existing authoritative `present_biome()` path updates all three layers together, which preserves exact transition timing without modifying the line-limited map controller.[4] The router exposes weather metrics with the existing feedback diagnostics and applies the same Ambience preference to both environmental layers.

## Intensity and enemy-cue protection

The weather node discovers the live hazard controller through a dedicated `weather_audio_source` scene group. Hazard activity is sampled on a bounded interval rather than every audio frame. Desert tornadoes and sandstorms raise the desert target intensity. Deep-biome events raise the local biome’s intensity while active. The system also supports an explicit source binding for deterministic tests.

Intensity eases toward its target instead of stepping. Base intensity remains audible in every biome, active hazards add no more than 25% linear gain, and the final runtime gain never exceeds the biome profile. When the shared enemy-audio router reports a newly played attack or warning cue, weather applies a short **−4.5 dB duck**, holds briefly, then releases smoothly. Movement sounds do not trigger ducking. This protects telegraph readability without silencing the world.

| Behavior | Contract |
|---|---:|
| Weather voices | 2 maximum |
| Biome crossfade | 2.4 seconds, constant power |
| Hazard sampling | 0.20 seconds |
| Intensity smoothing | 1.8 gain units per second |
| Enemy attack duck | −4.5 dB |
| Duck hold | 0.35 seconds |
| Duck release | 0.70 seconds |
| History/telemetry | Bounded counters and last-state snapshot only |

## Accessibility and failure behavior

Setting Ambience volume to zero stops both existing ambience and weather players and keeps them stopped until the preference becomes positive. Music and SFX controls remain independent. Headless mode records transitions, intensity, duck requests, asset selection, and voice capacity without requiring an output device. Missing streams, missing hazard sources, and rapid biome changes degrade to the quiet base layer; they never allocate unbounded voices or affect gameplay state.

## Acceptance criteria

The implementation is complete when all four weather files load and loop, biome changes crossfade between correct assets, only two weather voices exist, live hazard activity raises only the matching biome layer, enemy warning or attack playback produces a bounded weather duck, movement cues do not duck weather, Ambience mute stops both environmental systems, all resources are present in Web export metadata, and the synchronized `main` branch passes import, lint, loop analysis, contract tests, complete smoke validation, headless boot, and windowed audio-state certification.

## References

[1]: https://github.com/junnyboi/proto-isometric/blob/8d7d96e80e8f36dee39d7d7c1e2330d7fc960851/scripts/biome_soundscape.gd "Existing biome ambience controller"
[2]: https://github.com/junnyboi/proto-isometric/blob/8d7d96e80e8f36dee39d7d7c1e2330d7fc960851/scripts/fauna_telegraph_audio.gd "Specialized enemy audio router"
[3]: https://github.com/junnyboi/proto-isometric/blob/8d7d96e80e8f36dee39d7d7c1e2330d7fc960851/scripts/audio_service.gd "Audio bus and preference service"
[4]: https://github.com/junnyboi/proto-isometric/blob/8d7d96e80e8f36dee39d7d7c1e2330d7fc960851/scripts/feedback_router.gd "Authoritative feedback and biome presentation router"


## Windowed certification notes

A real Godot 4.7.2 Xvfb run exercised all four runtime weather resources through the production controller. The final 1280×720 capture confirmed one active voice inside the hard two-voice cap, completed 2.4-second biome transitions, matching hazard boosts for Desert, Wetlands, Frozen Tundra, and Lava Fields, distinct base mix levels, and an active −4.5 dB Kilnheart attack duck on the volcanic layer. The refitted dashboard completed with no script errors, leaked nodes, retained audio resources, or clipped biome identities.
