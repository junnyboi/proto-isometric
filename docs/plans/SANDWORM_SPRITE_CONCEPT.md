# Ironjaw Dune Burrower — Segmented Sprite Concept

## Purpose and diagnosis

The current desert sandworm is readable as a target but looks like temporary debug art: uniform circles, flat brown fills, identical body beads, and a symbolic mouth. The replacement must remain instantly readable at Walker’s Wake’s gameplay zoom while matching the painterly, high-detail, organic-mechanical enemy language established by the Mud Skimmer, Rime Stalker, Cinder Crawler, and biome-specific tiny mobs.

## Chosen concept

**Ironjaw Dune Burrower** is a desert annelid whose natural ferro-chitin has mineralized into overlapping armor plates. Its silhouette combines a wedge-shaped tunneling head, a black recessed tri-mandible maw, plated annular body sections, flexible dark connector tissue, and a tapered finned tail. Weathered rust-red shell plates blend into desert terrain; pale sandstone cutting edges and restrained cyan sensory pits echo Walker’s Wake’s industrial-biological setting without making the creature look mechanical.

The creature must feel heavy, old, and adapted to abrasive sand. Its armor uses chipped edges, layered plate seams, sparse pitting, and dust wear rather than glossy fantasy scales. The head is the focal point and clearly indicates attack direction. Body segments overlap enough to form one organism instead of a chain of disconnected icons.

| Element | Visual role | Runtime behavior |
|---|---|---|
| Head | Wedge/plow silhouette, dark circular maw, three pale mandibles, two cyan sensory pits | Leads movement and attack direction; enlarges subtly during Expose; receives hover and hit tint |
| Body segment | Flattened armored annulus, paired dorsal plates, dark flexible connector at both ends | Repeated three times with phase-shifted lateral undulation and slight scale taper |
| Tail | Tapered armored cone with two sand-slicing fins and a dark connector socket | Final segment; swings more widely during Expose and fades first during Dive/dispersal |

## Camera, lighting, and modular constraints

Every asset uses the same southeast-facing three-quarter isometric camera and soft upper-left key light as existing enemies. The production masters are isolated on true transparency, with no cast shadow, dust cloud, text, frame, border, terrain, checkerboard, or background color. Every part points horizontally to screen-right so Godot can rotate the modular chain to the committed attack direction. The connector centerline must pass through the exact horizontal center of each canvas.

The head, body, and tail each occupy roughly 74% of a square master canvas, leaving safe transparent margins for rotation. Their outer silhouettes must remain complete. Connector openings on adjacent pieces must share the same thickness and dark tissue color so overlap hides seams. The head must remain recognizable when displayed at approximately 96 pixels; body and tail pieces must remain readable at 62–72 pixels.

## Palette and materials

| Material | Target color family | Intent |
|---|---|---|
| Main ferro-chitin | Rust umber `#7B3E2E` through clay `#A75D3F` | Desert-native mass and visual continuity |
| Cutting edges | Sandstone gold `#D7AD68` through pale bone `#E8D2A0` | Mouth and silhouette readability |
| Flexible joints / maw | Near-black oxblood `#261818` | Deep articulation and threat |
| Sensory pits | Restrained cyan `#58D8D1` | Shared world technology/biology accent, never a glow-dominant effect |
| Wear | Dust tan `#C89058`, charcoal chips | Abrasion and age |

## Animation and state presentation

The chain uses four trailing parts: three body segments and one tail. Segment centers follow the negative facing vector with 28–32 pixel spacing and a sine-wave lateral displacement. The wave amplitude increases toward the tail, producing a coherent body wave rather than identical bobbing circles. Expose raises opacity and scale over the breach interval. Dive reverses the presentation. Hit feedback tints the full chain pale for the existing hit-flash window. Hover tint remains warm gold. Stagger desaturates slightly and reduces wave speed. Health, telegraphs, attack timing, targeting, collision, rewards, and state transitions remain deterministic gameplay logic.

## GPT Image 2 production prompts

The three prompts use the same identity anchors and differ only by anatomical part.

### Head

Create a single transparent-background game sprite for Walker’s Wake: the HEAD of the “Ironjaw Dune Burrower,” a massive desert sandworm with organic ferro-chitin armor. Three-quarter isometric top-down camera, creature points horizontally to screen-right, exact side-facing centerline. Wedge-shaped tunneling skull; overlapping rust-umber and clay-red armor plates; chipped pale sandstone cutting rim; deep black circular maw with three short pale mandibles; two tiny restrained cyan sensory pits; dark flexible neck connector centered on the left edge of the anatomy. Painterly high-detail 2D game art, grounded science-fantasy, same material density as a premium isometric action game. Soft upper-left key light, crisp complete silhouette, readable at 96 pixels. True transparent alpha background. No body segments, no tail, no terrain, no cast shadow, no dust, no text, no border, no frame, no checkerboard, no green-screen or magenta-screen background.

### Body segment

Create a single transparent-background game sprite for Walker’s Wake: one modular ARMORED BODY SEGMENT of the same “Ironjaw Dune Burrower.” Three-quarter isometric top-down camera, segment axis points horizontally left-to-right through the exact canvas center. Flattened annular desert-worm segment with overlapping rust-umber and clay-red ferro-chitin plates, paired dorsal armor ridges, chipped sandstone-gold edges, sparse dust abrasion, and matching near-black flexible connector tissue visible at both left and right ends. Painterly high-detail 2D game art, grounded science-fantasy, identical lighting and materials to the matching head. Soft upper-left key light, complete isolated silhouette, designed to overlap neighboring copies and remain readable at 68 pixels. True transparent alpha background. No head, no mouth, no tail, no legs, no terrain, no cast shadow, no dust cloud, no text, no border, no frame, no checkerboard, no green-screen or magenta-screen background.

### Tail

Create a single transparent-background game sprite for Walker’s Wake: the TAIL segment of the same “Ironjaw Dune Burrower.” Three-quarter isometric top-down camera, tail tapers toward screen-left while its dark flexible connector socket is centered on the right, exact horizontal centerline. Tapered rust-umber ferro-chitin cone with two compact sand-slicing side fins, chipped sandstone-gold plate edges, clay-red layered armor, dusty abrasion, and a blunt armored digging tip rather than a stinger. Painterly high-detail 2D game art, grounded science-fantasy, identical lighting and materials to the matching head and body segment. Soft upper-left key light, complete isolated silhouette, readable at 62 pixels. True transparent alpha background. No head, no mouth, no extra segments, no legs, no terrain, no cast shadow, no dust cloud, no text, no border, no frame, no checkerboard, no green-screen or magenta-screen background.

## Acceptance gates

All three masters must share material language, connector height, camera, and lighting. The silhouettes must survive 512×512 runtime downsampling and in-game reduction. No edge-connected opaque background may remain. The head must clearly point toward attack direction; repeated body pieces must visually overlap; the tail must terminate the chain. Generated art replaces only the exposed sandworm anatomy—procedural dust wake and telegraph effects remain because they communicate gameplay state rather than creature anatomy.
