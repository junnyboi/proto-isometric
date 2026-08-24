# Walker’s Wake Biome BGM Redesign — Concept Proposal

**Author:** Manus AI  
**Version:** 2.0 proposal  
**Objective:** Replace the first biome soundtrack suite with a more organic, acoustic, and environmentally embodied score while preserving gameplay clarity, loopability, and the existing four-biome Music-bus integration.

## Creative thesis

The revised suite will sound as though **musicians are performing inside each landscape**, rather than as though a synthesizer is describing it. Bowed strings, plucked strings, low winds, breathy reeds, wooden percussion, drums, metal, and human voices will carry the score. Electronic layers will be reduced to nearly inaudible support for sub-bass continuity and will never be the defining timbre.

Environmental events will function as part of the orchestration. Sand shifts will become brushed rhythm; water bubbles and droplets will become pointillistic percussion; blizzard gusts and ice fractures will become transitions; volcanic blasts, fireballs, flame jets, and lava churn will become deep accents and risers. These effects will remain spatial and rhythmically placed so that they enrich the world without masking Walker movement, impacts, warnings, or UI cues.

> The two user references are treated only as **high-level emotional and production guidance**. The regenerated music will not reproduce any existing melody, harmony, lyric, motif, arrangement, vocal phrase, or recording.

## Shared suite identity

All four tracks will retain an original **three-note descending expedition motif**, now performed by acoustic instruments rather than synthetic leads. The recurring motif connects the biomes while its orchestration changes with the environment. Each cue will target approximately 100 seconds, maintain moderate dynamics for extended traversal, and return to a compatible opening state for cyclic post-processing.

| Design dimension | Revised direction |
|---|---|
| Primary palette | Live-feeling strings, winds, reeds, wood, skin drums, stone, metal, and environmental recordings |
| Synthetic content | Minimal sub-bass or inaudible support only; no prominent pads, arpeggiators, synthetic brass, or electronic lead sounds |
| Performance feel | Human timing, bow noise, breath, finger movement, resonant rooms, and natural dynamic variation |
| Environmental sound | Musicalized but recognizable; placed in gaps and transitions rather than layered constantly |
| Gameplay mix | Strong low-frequency identity with restrained upper-midrange density and no continuous wall of sound |
| Loop behavior | Closing texture and harmony mirror the opening; runtime derivatives receive a four-second cyclic seam crossfade |
| Biome transitions | Existing interruptible equal-power two-voice crossfade on the `Music` bus remains unchanged |

## Biome concepts

### Desert — “The Breathing Expanse”

The desert cue will feel ancient, immense, wind-sculpted, and human. Its core ensemble will use low bowed strings, dry plucked strings, frame drums, hand percussion, and breath-rich double-reed or wooden flute colors. Shifting sand, wind through rock openings, granular dune movement, and distant dust impacts will be woven into the pulse.

A **solo contralto or mezzo voice** will appear sparingly in long, melismatic calls, answered by a very distant small ensemble. The text will use a wholly invented phonetic language with no semantic meaning and no quotation or approximation of real lyrics. Proposed syllables include: *Aruun na seya, khorai ema, talu shen, oruun ka*. The performance should feel ritualistic and windswept, but the vocal line must remain original and subordinate to gameplay.

| Attribute | Direction |
|---|---|
| Tempo / mode | 74 BPM; dark modal center with an augmented second used sparingly |
| Acoustic leads | Contralto vocalise, breathy double reed, solo cello, low violas |
| Rhythm | Frame drums, brushed skin, dry plucked strings, sand-grain shuffle |
| Environment | Howling crosswind, dunes shifting, sand pouring, distant dust collapse |
| Peak intensity | 6/10; majestic but never trailer-like |

### Oasis / Wetlands — “Water Under the Reeds”

The wetland cue will be humid, mysterious, fertile, and cautiously welcoming. It will center on warm cello and viola lines, bass clarinet, alto flute, breathy reed pipes, wooden slit-drum colors, and delicate plucked strings. Water bubbles, rising air pockets, reed rustle, droplets, shallow splashes, and submerged resonance will create a living rhythmic bed.

The music should suggest that the biome is breathing through water. No vocals will be used. Melodies will be short, organic, and conversational, leaving long spaces where bubbles and reed movement can answer the instruments.

| Attribute | Direction |
|---|---|
| Tempo / mode | 70 BPM; suspended Dorian color |
| Acoustic leads | Alto flute, bass clarinet, cello, viola, soft plucked strings |
| Rhythm | Hollow wood, hand percussion, droplets, bubble clusters |
| Environment | Water bubbles, mud suction, reed rustle, soft splashes, distant wet fauna |
| Peak intensity | 5/10; wonder with underlying uncertainty |

### Frozen Tundra — “White Distance”

The frozen cue will be vast, fragile, exposed, and quietly determined. Long string harmonics, tremolo violins, low cellos, contrabass, bass flute, oboe, and sparse wooden or bone-like flute tones will replace synthetic glass pads. Natural bow friction and breath will remain audible.

Howling wind will travel across the stereo field, with snow sweep, ice groans, distant cracks, and occasional crystalline impacts marking structural changes. The environmental layer should feel physically cold without turning into horror or holiday music. No vocals will be used.

| Attribute | Direction |
|---|---|
| Tempo / mode | 66 BPM; minor center with open fifths |
| Acoustic leads | String harmonics, solo cello, bass flute, oboe, low contrabass |
| Rhythm | Snow-muted drum, bow pulses, sparse wood and ice strikes |
| Environment | Howling blizzard, snow sweep, ice cracking, frozen metal resonance |
| Peak intensity | 5/10; endurance rather than triumph |

### Lava Fields — “The Mountain Answers”

The volcanic cue will be the most physically forceful track: heavy, ritualistic, dangerous, and controlled. Low cellos and contrabasses, aggressive viola ostinati, contrabassoon, bass clarinet, a piercing reed used only at peaks, large barrel drums, stone impacts, gongs, and iron will form the ensemble.

A **low male strong-voice choir** will sing in unison and octaves using short, invented monosyllables. The writing will emphasize grounded chest resonance, disciplined attacks, antiphonal answers, pentatonic-inflected contour, and ceremonial weight, while remaining an original fantasy language and composition. Proposed nonsemantic syllables include: *Khor, draan, tu, reng, shao, va*. The choir must not quote or resemble any existing lyric or melody.

Volcano explosions, fireball fly-bys and impacts, flamethrower-like flame jets, lava bursts, ember showers, and subterranean rumble will be arranged as dramatic accents. Explosions will be deep and distant rather than sharp enough to obscure combat telegraphs.

| Attribute | Direction |
|---|---|
| Tempo / mode | 80 BPM; dark Phrygian center with pentatonic vocal contours |
| Acoustic leads | Low male choir, cellos, contrabasses, contrabassoon, bass clarinet |
| Rhythm | Barrel drums, stone, gong, iron, stomps |
| Environment | Volcano blasts, fireballs, flame jets, lava churn, ember showers |
| Peak intensity | 7/10; the suite’s strongest cue, but not a continuous climax |

## Arrangement and mixing rules

Each track will begin with environment and one acoustic voice, grow into a traversal pulse, reach one controlled mid-track expansion, and return to a sparse state compatible with its opening. Environmental events will be **episodic** rather than constant. Vocals will be exclusive to Desert and Lava Fields, and both will use invented nonsemantic language.

The runtime pipeline will normalize the regenerated masters, resample them to 48 kHz stereo, create cyclic boundaries with a four-second tail-to-head crossfade, encode Ogg Vorbis assets, preserve the existing filenames, and therefore require no scene or save migration. The Music and Ambience sliders will remain independently functional.

## Acceptance criteria

| Gate | Acceptance condition |
|---|---|
| Organic timbre | Strings and winds are clearly dominant; synthetic layers do not define the cue |
| Environmental identity | Every requested biome effect is audible but does not become continuous noise |
| Vocal originality | Desert and volcanic vocals use invented language and entirely original melodic material |
| Gameplay suitability | No clipping, no excessive loudness, and sufficient spectral room for SFX and warnings |
| Runtime integrity | Four distinct 48 kHz stereo Ogg tracks load, loop, crossfade, and mute through the Music bus |
| Repository quality | Full lint, import, smoke, boot, and windowed playback validation pass before handoff |
