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
