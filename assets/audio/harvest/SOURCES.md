# Protos Harvest chore SFX runtime sources

The four mono PCM WAV files were extracted from approved **Mirelo SFX carriers** on 2026-08-25 and copied byte-for-byte from the prepared external package. They are played through the existing bounded `AudioService` world-SFX pool.

| Runtime file | Format | SHA-256 |
|---|---|---|
| `hoe_soil.wav` | PCM 16-bit mono, 48 kHz | `b5434063060f58a32e52d6f817fe5cfeac0024a085263869aee0ec42571525f5` |
| `water_pour.wav` | PCM 16-bit mono, 48 kHz | `3198a0c2de36633ef2cc77b962689d51529af9ae6012e6301e9fee632109a87f` |
| `harvest_pluck.wav` | PCM 16-bit mono, 48 kHz | `856d93db0e4c38d2d26e0ccacdcefa39dc71763fcee9fa276189fe67917d0547` |
| `shipping_drop.wav` | PCM 16-bit mono, 48 kHz | `32fafa06c7fe42fd247dacfe901087765795c34981204830d09942273f9e5e76` |

## Clearing music

The woodland day, night, and rain instrumentals were generated with the built-in latest music model on 2026-08-25 using the approved Protos Harvest palette. Source outputs were decoded to 48 kHz stereo PCM16, then converted into sample-accurate loops by crossfading each final three-second tail into its opening and rotating the resulting seam to the file start. `BiomeMusic` applies bounded equal-power transitions and never restarts an unchanged clearing track.

| Runtime file | Duration | SHA-256 |
|---|---:|---|
| `music_clearing_day_loop.wav` | 84.040 s | `ea580373a64695f7f1ab9641105d8dd1f671e6296b15693afb24b4c40b783ff1` |
| `music_clearing_night_loop.wav` | 86.574 s | `1bdbc16443c349294bbf35d47ba04694c7dac3961f15249452a6aeeb53363e21` |
| `music_clearing_rain_loop.wav` | 82.865 s | `3ace55de1260adc7d2b719a9cdd49c9ce4fe7e5034a16b3803fd6dfa59fa1bdb` |

## Title music

`bgm_title.ogg` (**Home Signal**) was generated with the built-in latest music model on 2026-08-25 as an original 72 BPM D-Dorian instrumental for the Protos Harvest title screen. Its sparse felt piano, hammered-metal motif, strings, analog air, and restrained clockwork pulse are designed to sit beneath menu interaction. The generated source was decoded to 48 kHz stereo PCM16, converted into a sample-accurate loop with a three-second tail-to-head crossfade, rotated to a low-discontinuity seam, and encoded as Vorbis for efficient Web delivery. The title scene plays it on the Music bus at `-9 dB` and applies a bounded `0.65 s` fade before the field music starts.

| Runtime file | Duration | Format | SHA-256 |
|---|---:|---|---|
| `../bgm_title.ogg` | 85.529 s | Ogg Vorbis, 48 kHz stereo | `1821b40e5350d8af2d203d3e56d548ced0a5ed74e58ff117c4bc82ef03cff621` |
