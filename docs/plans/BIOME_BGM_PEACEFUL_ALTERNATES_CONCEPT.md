# Walker’s Wake Peaceful Biome Alternates — Concept

**Author:** Manus AI  
**Purpose:** Add one softer long-form alternate score to each biome while preserving the existing acoustic identity, gameplay readability, seamless looping, and terrain-border crossfades.

## Direction

The new cues represent the quieter intervals between threats. They should feel like musicians listening to each landscape rather than pushing the player forward. Every arrangement is sparse, slow, acoustic-forward, and nearly percussion-free. Long bows, breathy winds, isolated plucked notes, natural room tone, and environmental textures carry motion. There are no drum grooves, trailer impacts, ostinatos, aggressive pulses, or sudden peaks. All four alternates are instrumental so they contrast clearly with the vocal signatures in the existing Desert and Lava Fields primary cues.

| Biome | Alternate identity | Acoustic palette | Environmental layer |
|---|---|---|---|
| Desert | **Night Sand, Open Sky** | Solo cello, viola harmonics, ney-like wooden flute, sparse oud-like plucks | Gentle howling wind, close sand grains shifting, distant dune slides |
| Wetlands | **Still Water Lanterns** | Alto flute, bass clarinet, soft cello, harp harmonics, occasional wooden chime | Water bubbles, small ripples, reed movement, distant droplets and insects |
| Frozen Tundra | **Aurora Under Snow** | High string harmonics, soft cello, bass flute, breathy oboe, faint glass resonance | Wide howling wind, powder snow, distant ice groans and tiny crystalline cracks |
| Lava Fields | **Embers After the Storm** | Low cello and contrabass, bass clarinet, contrabassoon, sparse bowed metal | Low lava bubbles, soft ember hiss, distant muffled volcanic breaths, occasional far rockfall |

## Generation and runtime contracts

Each master targets approximately **100 seconds**. Runtime processing will normalize the alternates below their primary counterparts and construct a genuine cyclic boundary with the same deterministic tail-to-head crossfade recipe already used by the project. The alternate cues should land near **-18 LUFS integrated** before the existing per-biome Music-player gain, leaving them perceptibly quieter than the primary cues while preserving the user’s Music slider as the final authority.

Each biome will expose a two-track pool. Selection will use a seeded shuffle bag: both tracks are played once per bag in randomized order, bag boundaries avoid immediate repeats, and tests may inject a fixed seed. Biome-border changes retain the existing two-voice equal-power transition. The chosen stream path and variant index will be visible in runtime metrics for smoke testing and diagnostics.

The loop gate, export allowlist, source ledger, and live-map gameplay smoke must cover all eight Ogg files before merge.
