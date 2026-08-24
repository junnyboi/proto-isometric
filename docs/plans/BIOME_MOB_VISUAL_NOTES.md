# Biome Mob Visual Reference Notes

The existing hostile-fauna sprites use a **transparent 512 × 512 RGBA canvas**, a centered three-quarter isometric creature view, and generous clear padding around the silhouette. Subjects face generally down-right, which works with the game’s southeast-oriented isometric projection.

The rendering style is detailed painterly concept art with slightly pixel-stepped edges at native resolution rather than strict low-resolution pixel art. The creatures combine organic anatomy with weathered mechanical armor, use dark internal joints, and reserve bright emissive accents for small focal details. Silhouettes are broad, readable, and biome-coded: wetland uses teal/brown corroded shell plates with mossy growth, while frozen uses white segmented armor, dark machinery, and translucent blue ice spines.

For tiny mob sprites, the new set should preserve the same material language and isometric viewpoint but simplify interior detail, exaggerate one biome-specific silhouette feature, maintain true transparent backgrounds, and remain legible when drawn at roughly 38–48 gameplay pixels. Each final file should keep a centered subject, complete extremities, no cast shadow, no text, and no environmental backdrop.

## Generated master review

The Glassback Scarab master clearly satisfies the desert identity: the amber carapace, broad body, thick forked mandibles, and low six-leg silhouette are readable. The Mire Tick master is strongly differentiated by its teal seed-pod abdomen, splayed legs, moss growth, cyan sensors, and circular mouth. Both masters retain complete silhouettes and consistent southeast-facing isometric presentation.

Both generated files contain edge-connected temporary key-color remnants and horizontal key-color streaks outside the subject. These are deterministic cleanup artifacts rather than creature defects: runtime preparation must remove all edge-connected key-color regions, decontaminate one-pixel color fringes, crop to the surviving alpha bounds with padding, center the result, and downsample to 512 × 512 RGBA.
The Rime Shardling master has the intended white ceramic shell, strong three-crystal crown, hooked claws, and cyan focal eye. The Ember Skitter master has a distinct obsidian silhouette, two furnace vents, and clear orange magma seams. Both are compositionally consistent with the first pair.

The Rime Shardling contains the same edge-connected magenta key-color streaks as the Mire Tick. The Ember Skitter instead arrived on an opaque dark teal background despite the transparency request, with a faint green fringe around the silhouette. Its runtime derivative therefore requires edge-connected background segmentation based on low saturation/dark teal continuity from the canvas border, conservative preservation of the creature’s internal black armor, alpha feathering at the cutout boundary, and green-fringe decontamination.

## Runtime derivative review

The 512 × 512 runtime derivatives preserve all four complete silhouettes and remain strongly differentiated in the 64 × 64 contact-sheet check over representative biome colors. Desert reads as warm amber and forked; wetland as a rounded teal pod; frozen as a bright triangular crystal crown; lava as a dark low shell traced by orange cracks. The Ember Skitter’s opaque master background was removed cleanly without erasing the black armor, and no large key-color streaks remain in any runtime asset.

## Windowed/Xvfb verification

A 1280 × 720 windowed OpenGL compatibility run under Xvfb exercised the real `MeleePressure` renderer with six spawned mobs per biome and one active contact telegraph in each panel. All four packs render without missing textures, clipping, opaque backgrounds, or key-color remnants. The small silhouettes are immediately separable by palette and shape, horizontal facing flips work across the encirclement positions, and the original warning line, target ring, and countdown marker remain readable above the new art.

Verification capture: `/home/ubuntu/biome-mob-work/biome_mob_visual.png` (SHA-256 `ba5d3d419bb73c61d2fb1784d4509cd9623a8eede402858419778eef4dbf743b`).
