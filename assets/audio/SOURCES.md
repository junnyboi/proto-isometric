# Audio Sources

`ui_begin.wav` — generated with Manus `generate_video` using Gemini Omni, trimmed to a 48 kHz stereo runtime WAV, and accepted by the user on 2026-08-14. Full generation history remains available in Git before commit `10292c0`.

`chassis_damage.wav` — generated with Manus `generate_video` using Gemini Omni after Mirelo was unavailable, extracted from an audio-bearing carrier, trimmed to a 2.05-second 48 kHz stereo runtime WAV, peak-controlled to -3.77 dBFS, and accepted by the user on 2026-08-16.

## J1 semantic Smash feedback

The J1 clips below are accepted mono PCM runtime derivatives prepared on 2026-08-20. `smash_swing.wav` was extracted and normalized from a built-in Gemini Omni generated-audio clip prompted as one isolated industrial mech-arm swing with no music, ambience, speech, or impact. The remaining clips are short deterministic edits and mixes of that accepted generated source and the shipped `chassis_damage.wav` cue. Edits include trimming, downmixing, resampling, filtering, pitch treatment, dynamics, and fades. Generation masters were deleted after the runtime WAVs passed codec, sample-rate, channel-count, and duration validation.

| Runtime file | Role |
|---|---|
| `smash_swing.wav` | Miss/whiff action cue |
| `fauna_contact.wav` | Standard fauna contact |
| `heavy_contact.wav` | Charged/heavy fauna contact |
| `stone_break.wav` | Dry/frozen/volcanic stone break family |
| `wet_wood_break.wav` | Wet wood/foliage break family |
| `fauna_defeat.wav` | Restrained fauna defeat confirmation |

## J2 locomotion and charge feedback

`servo_engage.wav`, `heavy_gait.wav`, `surface_step.wav`, `charge_detent.wav`, and `blocked_clank.wav` are compact mono PCM derivatives made from the accepted J1 generated/runtime sources. They use deterministic trimming, resampling, filtering, dynamics, pitch treatment, and fades; no new generation master was retained.

## Enemy telegraph warnings

The four cues below are accepted mono 48 kHz PCM runtime derivatives generated with built-in Mirelo on 2026-08-20. Each was prompted as an isolated, nonverbal pre-attack warning with no impact, music, ambience, or speech, then deterministically trimmed, filtered, peak-controlled, faded, and fitted inside its gameplay warning window. The Cinder Crawler derivative sequences three source transients to match its three marked salvo cells. Generation masters were deleted after runtime validation.

| Runtime file | Role | Duration |
|---|---|---:|
| `fauna_telegraph_sandworm.wav` | Granular seismic intercept warning | 0.62 s |
| `fauna_telegraph_mud.wav` | Wet suction and wake-sweep warning | 0.60 s |
| `fauna_telegraph_rime.wav` | Crystalline frost-pounce warning | 0.86 s |
| `fauna_telegraph_cinder.wav` | Three-beat ember-salvo warning | 1.05 s |

## Generated movement and objective cues

`impact_contact.wav`, `charge_ready.wav`, and `relay_complete.wav` were generated with Manus `generate_video(generate_audio:true)` after Mirelo was unavailable, extracted from audio-bearing carriers, silence-trimmed, peak-limited, and stored as 48 kHz mono PCM runtime WAVs on 2026-08-20. The impact sample can supply a lower-pitched weight layer; the charge sample supplies the pickup voice. Generation carriers remain outside Git.

## J6 biome ambience beds

`ambience_desert.wav` is an accepted mono PCM runtime derivative extracted from an eight-second Gemini Omni audio-bearing generation prompted as a restrained mechanical desert wasteland bed. `ambience_wetland.wav`, `ambience_frozen.wav`, and `ambience_volcanic.wav` are deterministic spectral derivatives of that accepted source, mixed with low-level procedural noise or sub-bass appropriate to each biome after additional generator requests encountered temporary capacity limits. All four beds are 22.05 kHz mono PCM, use short boundary fades, play at a restrained runtime level, and share a hard two-voice crossfade cap. The generation carrier was deleted after codec, channel, sample-rate, duration, and size validation.

## Biome background music suite

The four `bgm_*.ogg` files are v2 runtime derivatives of original masters regenerated with built-in **Lyria 3 Pro** on 2026-08-24. This revision deliberately replaces prominent synthetic scoring with live-feeling bowed and plucked strings, winds, reeds, skin drums, wood, stone, metal, human breath, and biome-specific environmental events. A shared original three-note descending expedition motif connects the suite.

Desert alone includes sparse contralto calls in a wholly invented nonsemantic language; Lava Fields alone includes a disciplined low male strong-voice choir using short invented fantasy syllables. The vocal prompts prohibit real-language lyrics, recognizable melodies, quotation, and imitation of existing vocal writing. Wetlands and Frozen Tundra remain instrumental.

Runtime treatment is deterministic: each generated stereo master was decoded, loudness-normalized to a restrained gameplay target of approximately -18 LUFS with a -1.5 dB true-peak ceiling, resampled to 48 kHz stereo, turned into a cyclic loop by crossfading its tail into its opening over four seconds, stripped of metadata, and encoded as Ogg Vorbis. Godot loops each stream and crossfades biome changes through a hard two-voice cap on the `Music` bus.

| Runtime file | Acoustic and environmental identity | Runtime duration |
|---|---|---:|
| `bgm_desert.ogg` | Low strings, plucked gut strings, woodwinds, frame drums, contralto calls, howling wind, and shifting sand | 93.6 s |
| `bgm_wetland.ogg` | Cellos, violas, alto flute, bass clarinet, reeds, hollow wood, water bubbles, droplets, and mud movement | 92.7 s |
| `bgm_frozen.ogg` | Tremolo strings, harmonics, cello, bass flute, oboe, blizzard wind, snow sweep, ice groans, and distant cracks | 92.3 s |
| `bgm_volcanic.ogg` | Low strings, contrabassoon, bass clarinet, barrel drums, male choir, volcano blasts, fireballs, flame jets, lava, and embers | 90.1 s |

## Peaceful biome BGM alternates

The four `bgm_*_alt.ogg` files are original instrumental masters generated with built-in **Lyria 3 Pro** on 2026-08-24. They provide a quieter traversal state for each biome using sparse acoustic strings and winds, near-zero percussion, environmental field textures, and no vocals. They intentionally contrast with the more active primary cues without changing the established biome identity.

Runtime treatment follows the primary suite’s deterministic loop process, with a quieter target of approximately -19 LUFS and a -2.0 dB true-peak ceiling. Each master was resampled to 48 kHz stereo, transformed into a cyclic loop by crossfading its tail into its opening over four seconds, stripped of metadata, and encoded as Ogg Vorbis.

| Runtime file | Peaceful acoustic and environmental identity | Runtime duration |
|---|---|---:|
| `bgm_desert_alt.ogg` | Cello, viola harmonics, wooden flute, muted plucks, gentle wind, sand grains, and distant dune slides | 92.7 s |
| `bgm_wetland_alt.ogg` | Alto flute, bass clarinet, cello, harp harmonics, water bubbles, ripples, reeds, and distant insects | 93.1 s |
| `bgm_frozen_alt.ogg` | String harmonics, cello, bass flute, oboe, bowed glass, wide wind, powder snow, and remote ice groans | 92.7 s |
| `bgm_volcanic_alt.ogg` | Low cello, contrabass, bass clarinet, contrabassoon, bowed metal, lava bubbles, ember hiss, and distant rockfall | 91.0 s |

Godot exposes a two-track pool per biome. A seeded shuffle bag randomizes which cue plays first, guarantees both primary and alternate cues are selected once per bag, and prevents immediate repeats across bag boundaries. The existing bounded equal-power Music-bus crossfader handles both biome changes and same-biome track rotation.


## Biome enemy movement and attack cues

The twelve files under `assets/audio/enemies/` were generated on 2026-08-25 from original audio-bearing carrier videos created with the built-in video generation service. Each carrier used a 16:9 keyframe assembled from the shipped creature sprite and requested one isolated dry sound effect with no music, ambience, dialogue, or narration. The carriers remain under the ignored `.generated/` working directory. `tools/extract_enemy_sfx_from_carriers.py` deterministically extracts the audio, trims silence, converts it to mono 48 kHz PCM, applies conservative normalization and boundary fades, and enforces the target duration.

| Runtime file | Enemy and trigger | Duration |
|---|---|---:|
| `enemies/mob_glassback_move.wav` | Glassback Scarab dry chitin-and-sand movement cadence | 0.75 s |
| `enemies/mob_glassback_attack.wav` | Glassback Scarab glassy mandible warning and lunge | 0.60 s |
| `enemies/mob_mire_tick_move.wav` | Mire Tick damp leg taps and mud movement cadence | 0.80 s |
| `enemies/mob_mire_tick_attack.wav` | Mire Tick wet needle snap warning and bite | 0.65 s |
| `enemies/mob_rime_shardling_move.wav` | Rime Shardling brittle ice-skitter cadence | 0.80 s |
| `enemies/mob_rime_shardling_attack.wav` | Rime Shardling crystalline chirp and ice-crack warning | 0.70 s |
| `enemies/mob_ember_skitter_move.wav` | Ember Skitter coal scrape and ember-hiss cadence | 0.80 s |
| `enemies/mob_ember_skitter_attack.wav` | Ember Skitter furnace bite and cinder-spit warning | 0.70 s |
| `enemies/boss_kilnheart_move.wav` | Kilnheart Colossus basalt footfall and furnace movement cadence | 1.25 s |
| `enemies/boss_kilnheart_forge_sweep.wav` | Kilnheart Forge Sweep warning and release signature | 1.30 s |
| `enemies/boss_kilnheart_magma_ram.wav` | Kilnheart Magma Ram charge-lane signature | 1.35 s |
| `enemies/boss_kilnheart_caldera_barrage.wav` | Kilnheart three-pulse Caldera Barrage signature | 1.50 s |

`FaunaTelegraphAudio` routes these files spatially through the existing `Enemy` bus. Tiny-mob movement uses a per-entity staggered cadence and low priority so a pack cannot create an unbounded voice burst. Attack cues are deduplicated by enemy ID and attack serial at the warning transition. Kilnheart movement is emitted only when its combat model reports actual displacement, while its selected attack pattern chooses the corresponding boss cue. Accessibility SFX preferences and the global spatial voice cap remain authoritative.


## Biome weather ambience layers

The four files under `assets/audio/weather/` were generated on 2026-08-25 from original ten-second audio-bearing weather carriers created with the built-in video generation service. Each carrier used a generated 16:9 environment reference and requested one continuous biome-specific weather texture with no dialogue, narration, music, rhythm, animals, UI, or combat effects. Carrier videos and references remain under the ignored `.generated/weather_audio/` workspace and do not ship.

`tools/extract_weather_audio_from_carriers.py` takes a stable interior source window, converts it to mono 48 kHz PCM, constructs an exact eight-second cyclic loop by equal-power tail-to-head overlap, matches −34 LUFS integrated through deterministic constant gain, and validates sample count, channel count, distinct hashes, nonzero energy, conservative peaks, edge-energy compatibility, and seam discontinuity. Godot 4.7.2 loads all four outputs as `AudioStreamWAV` resources and enables forward looping at runtime.

| Runtime file | Weather identity | Duration | Integrated loudness | Seam jump | SHA-256 |
|---|---|---:|---:|---:|---|
| `weather/weather_desert_glasswind.wav` | Dry crosswind and fine granular sand hiss | 8.000 s | −34.0 LUFS | 0.001617 | `409d58cc0a1ac807fc19e711ea5168250cc02f8fc5a3ef963d3fb2f592299818` |
| `weather/weather_wetland_reedrain.wav` | Light rain on reeds and shallow water | 8.000 s | −34.0 LUFS | 0.004639 | `a9c5cae6482e13da601fec402a3927a25ef0ecf7d23f9402fb8bdb8c7dbf529b` |
| `weather/weather_frozen_whiteout.wav` | Airy blizzard wash and ice-crystal skitter | 8.000 s | −34.0 LUFS | 0.000885 | `9bdae6d7f88eb133e5b1b79ca90c996ffc791552d88b3b249215dbbfb4e29d52` |
| `weather/weather_volcanic_ashfall.wav` | Ash wind, geothermal rumble, and sparse ember crackle | 8.000 s | −34.0 LUFS | 0.000336 | `4fc6a3f6030140831661b024b058a0c56e4a5f74cda1fc00ee43940655d01e95` |

These loops form a second environmental layer beneath actionable `Enemy`-bus cues. They share the existing `Ambient` bus and Ambience accessibility preference, use a hard two-voice crossfade cap, raise intensity only for matching live hazard activity, and apply a bounded duck when enemy warnings or attacks play.
