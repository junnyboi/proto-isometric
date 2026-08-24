# Ironjaw Apex Burrower — Boss Design and Production Contract

**Author:** Manus AI
**Status:** Implementation specification
**Engine target:** Godot 4.7.2
**Parent enemy:** Ironjaw Dune Burrower (`sandworm`)

## Encounter identity

The boss variant is the **Ironjaw Apex Burrower**, an old siege organism whose armor has fused with relic-metal and glassy desert minerals. It must read as the same species as the standard Ironjaw while carrying unmistakable encounter authority: a broader crown-shaped head, heavier layered plates, six body sections instead of three, a reinforced digging tail, a longer dust wake, a dedicated boss health bar, and phase-specific attack telegraphs.

The boss is a desert-only Alert III encounter. It appears once the third relay arms the highest alert, never replaces the standard worm, never spawns inside a sanctuary, and is recreated at full health if sanctuary dispersal removed it before defeat. After true defeat it cannot respawn during the run.

| Contract | Standard Ironjaw | Apex boss |
| --- | ---: | ---: |
| Kind | `sandworm` | `ironjaw_apex` |
| Maximum health | 4 | 12 |
| Body sections | 3 body + 1 tail | 6 body + 1 tail |
| Visual scale | 1.00× | 1.42× |
| Contact damage | 10 | 12 |
| Spawn rule | Ambient/alert budget | Desert Alert III, one living boss |
| Reward | Existing worm drop | Existing drop plus two boss bonus drops |
| Sanctuary rule | Disperse and cancel damage | Identical; may respawn after leaving until defeated |

## Armor phases and behavior

Armor stage is derived only from health, making save/replay behavior deterministic and preventing phase drift. Crossing a threshold triggers a one-time break reaction, cancels the current attack, emits debris feedback, and opens a bounded stagger window. The standard Ironjaw remains unchanged.

| Stage | Health | Visual set | Behavior | Break reaction |
| --- | ---: | --- | --- | --- |
| **Crowned Plate** | 12–9 | Intact apex head/body/tail | Deliberate triple-breach attacks; longest readable warning | None |
| **Faulted Carapace** | 8–5 | Cracked head and body, intact tail | Faster burrow/intercept cadence; faultline charge | 1.10 s stagger and attack cancellation |
| **Core Exposed** | 4–1 | Broken head/body, scorched tail tint | Fast repositioning; three-pulse ringquake during exposure | 0.72 s stagger and attack cancellation |

Stagger resistance increases as armor breaks. External stagger requests are capped at **1.10 s**, **0.72 s**, and **0.42 s** for stages zero, one, and two. This preserves counterplay while preventing the final phase from being permanently locked.

## Unique attack patterns

Every attack commits its targets at warning start and ignores later player movement. Damage is resolved at most once per target pulse. Entering sanctuary cancels unresolved pulses immediately. Large `delta` values may advance multiple states but cannot duplicate a committed attack serial.

| Pattern | Phase | Telegraph | Resolution | Safe response |
| --- | --- | --- | --- | --- |
| **Crown Breach** | Crowned Plate | Three amber target circles spread perpendicular to the committed approach, linked to the underground trail | At Intercept completion, one 12-damage tick if Walker is inside any breach circle | Leave the three circles or stand in marked lateral gaps |
| **Faultline Rush** | Faulted Carapace | Wide amber lane from attack origin through an overshot committed target; cyan side rails mark safety | At Intercept completion, one 12-damage tick if Walker is within the lane segment | Move perpendicular beyond the cyan rails |
| **Ringquake** | Core Exposed | Three concentric amber rings around the committed target; each ring counts down independently during Expose | Three timed 12-damage pulses, each checking only its narrow ring band and resolving once | Move between rings as each pulse advances outward |

The boss chooses its pattern directly from armor stage. It cannot randomize into an attack whose visual language does not match its current damage state.

## Burrow animation contract

Three generated transparent transition sprites replace the abrupt circle-only burrow presentation for both standard and boss worms. Each frame is a partial armored back crest moving through churned sand, seen in the same three-quarter isometric perspective as the body sprites.

| Frame | Visual content | Runtime use |
| --- | --- | --- |
| `burrow_01` | Low sand mound with one armor ridge and forward spray | Early Burrow, late Dive |
| `burrow_02` | Two visible plates, deeper furrow, larger dust crest | Mid Burrow/Intercept/Dive |
| `burrow_03` | Head crown and first plate breaking through sand | Late Intercept, early Dive |

Burrow and Intercept advance `01 → 02 → 03`; Dive reverses `03 → 02 → 01`. Frame selection is normalized from state progress and has no gameplay timing authority. Standard scale is **0.34×**; boss scale is **0.49×**. Existing ridgeline trails, target telegraphs, and dust remain behind the frame, while the frame remains below the fully exposed body.

## Generated asset specification

All assets are standalone 1024×1024 masters prepared into 512×512 transparent runtime PNGs. Subjects face screen-right on a true transparent background, use the established rust-red ferro-chitin, pale sandstone cutting edges, dark flexible seams, and restrained cyan sensory accents, and share upper-left lighting. No text, border, ground plane, cast shadow, checkerboard, frame sheet, detached debris outside the subject, or duplicate object is allowed.

| Runtime asset | Purpose |
| --- | --- |
| `ironjaw_apex_head.png` | Intact crown head with enlarged mandibles and relic-metal brow |
| `ironjaw_apex_body.png` | Intact modular boss body section with wide matching connectors |
| `ironjaw_apex_tail.png` | Intact reinforced digging tail |
| `ironjaw_apex_head_cracked.png` | Stage-one head with split plates and exposed dark seams |
| `ironjaw_apex_body_cracked.png` | Stage-one body with readable armor fractures |
| `ironjaw_apex_head_broken.png` | Stage-two head with missing plate sections and bright internal heat |
| `ironjaw_apex_body_broken.png` | Stage-two body with torn armor and exposed flexible core |
| `ironjaw_burrow_01.png` | Low armored sand crest |
| `ironjaw_burrow_02.png` | Medium armored sand crest |
| `ironjaw_burrow_03.png` | High pre-breach armored crest |

## Architecture and save/replay contract

The boss remains a dictionary entity managed by `sandworms.gd`, with new fields for `is_boss`, `armor_stage`, `attack_pattern`, `strike_targets`, `strike_pulses`, `resolved_pulses`, and one-time break bookkeeping. A dedicated `ironjaw_boss.gd` helper owns phase thresholds, timings, layout scale, attack-target construction, and geometric hit tests. `sandworm_visuals.gd` selects textures and sizes but never decides damage or state transitions. `worm_telegraph.gd` renders boss warnings from combat snapshots and never mutates combat.

## Acceptance criteria

The implementation is complete only when the standard four-health reference fight still passes unchanged; the boss has exactly 12 health; each threshold changes visuals and attack behavior once; all three boss patterns have committed deterministic targets and sanctuary cancellation; each damage pulse resolves at most once; the three burrow frames play forward and backward; boss rewards emit once; generated assets ship in the filtered Web PCK; and Xvfb captures visibly prove intact, cracked, broken, Crown Breach, Faultline Rush, Ringquake, emerge, dive, and defeat states.
