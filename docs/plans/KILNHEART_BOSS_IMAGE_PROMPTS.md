# Kilnheart Colossus GPT Image 2 Prompt Sheet

**Model:** GPT Image 2
**Scenario:** Transparent standalone game-character sprite pack
**Master target:** 1024×1024 PNG
**Runtime target:** 512×512 transparent PNG

## Shared visual contract

Create one original standalone 2D game-character sprite for an isometric industrial exploration game. The subject is the **Kilnheart Colossus**, a colossal six-legged volcanic forge beast with a broad low body, overlapping jagged obsidian armor, a visible white-orange molten core, a crown of short furnace vents, asymmetrical basalt crusher claws, and narrow cyan sensory slits. Render it in painterly high-detail 2D concept-sprite style with clean readable edges, strong silhouette, three-quarter isometric view facing screen-right, upper-left warm light, restrained orange emissive cracks, charcoal-black basalt, rust-red metal inclusions, and no ground tile. Keep anatomy and proportions identical across the full set. Show exactly one complete creature, centered with generous transparent margin and a centered lower contact point.

**Hard constraints:** true transparent background; no text, logo, watermark, border, UI, scenery, floor, cast shadow, frame sheet, duplicate creature, detached debris, smoke cloud, or cropped limbs.

## Asset prompts

| Asset | Pose and state delta from the shared contract |
|---|---|
| `kilnheart_idle_master.png` | Neutral alert stance. All six legs grounded, crusher claws half-open, furnace vents closed, intact shell, core visible but controlled. This image is the style and identity anchor. |
| `kilnheart_walk_a_master.png` | Locomotion frame A. Front-left, middle-right, and rear-left legs planted while opposite legs lift slightly; body shifts forward and down. Preserve exact identity and scale from the anchor. |
| `kilnheart_walk_b_master.png` | Locomotion frame B. Reverse the tripod gait: front-right, middle-left, and rear-right legs planted; body shifts forward and up. Preserve exact identity and scale. |
| `kilnheart_windup_master.png` | Attack windup. Body crouches low, six legs brace outward, crusher claws draw inward, furnace vents begin opening, and the molten core intensifies. No projectile or attack effect. |
| `kilnheart_attack_master.png` | Attack release. Crusher claws thrust forward, vents fully open, forebody rises, and the core burns white-orange. No external flames, projectile, target marks, or debris. |
| `kilnheart_cracked_master.png` | Stage-one damage state in the neutral pose. Several obsidian plates split, bright orange seams widen, one furnace vent bends, but all limbs and silhouette remain complete. |
| `kilnheart_broken_master.png` | Stage-two damage state in the neutral pose. Crown plates are missing, molten core is substantially exposed, armor edges glow, and one crusher claw is chipped; the creature remains combat-capable. |
| `kilnheart_defeat_master.png` | Defeat pose. The Colossus has collapsed low with folded legs, cooled dark plates, dim core, and closed claws. Keep one coherent body without detached rubble. |

Generate `kilnheart_idle_master.png` first without references. Generate every subsequent asset using the accepted idle master as the identity, camera, material, palette, and lighting reference.
