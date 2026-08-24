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

## Peaceful herd species cues

The eight `herd_*.wav` files below are accepted 48 kHz mono PCM runtime derivatives generated with built-in **Lyria 3 Pro** on 2026-08-21. Each master requested one isolated, nonverbal creature sound with no music, speech, rhythm, or environmental bed. Runtime treatment is deterministic: silence trimming, duration fitting, mono downmix, band limiting, loudness control, and short boundary fades. Generation masters remain outside Git; only the compact runtime derivatives are shipped.

| Species | Ambient cue | Defeat cue |
|---|---|---|
| Dune Grazer | Low hollow bray and sandy exhale | Falling bellow, sandy body thump, plate clack |
| Reedback | Airy reed chirrup and bubble pop | Descending reed honk, mud splash, fibrous clack |
| Rimehorn | Breath-driven glacial moan and crystal ping | Fading frost groan, ice crack, snow thump |
| Ember Ram | Warm basalt rumble and ember chuff | Falling molten bleat, basalt crack, ash thud |

## Biome background music suite

The four `bgm_*.ogg` files below are original instrumental masters generated with built-in **Lyria 3 Pro** on 2026-08-24. The suite uses a shared three-note descending expedition motif while giving each biome a distinct tempo, mode, instrumentation, and environmental texture. Prompts explicitly excluded vocals, recognizable existing melodies, and stylistic imitation of any existing soundtrack.

Runtime treatment is deterministic: each generated stereo master was decoded, loudness-normalized to a restrained gameplay target of approximately -18 LUFS with a -1.5 dB true-peak ceiling, resampled to 48 kHz stereo, turned into a cyclic loop by crossfading its tail into its opening over four seconds, stripped of metadata, and encoded as Ogg Vorbis. Godot loops each stream and crossfades biome changes through a hard two-voice cap on the `Music` bus.

| Runtime file | Biome role | Runtime duration |
|---|---|---:|
| `bgm_desert.ogg` | Monumental desert traverse with deep drums, bowed metal, wind, and granular sand | 84.3 s |
| `bgm_wetland.ogg` | Luminous wetland passage with airy reeds, water resonance, and wooden pulse | 93.9 s |
| `bgm_frozen.ogg` | Vast frozen crossing with bowed glass, crystalline tones, and snow-muted drums | 83.0 s |
| `bgm_volcanic.ogg` | Heavy lava-field drive with basalt strikes, ember texture, and subterranean pulse | 81.5 s |
