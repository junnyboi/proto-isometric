# Biome Weather Particle System — Production Contract

**Author:** Manus AI
**Engine target:** Godot 4.7.2
**Runtime scope:** Desert, Oasis Wetlands, Frozen Tundra, and Lava Fields

## Purpose and architectural choice

The project already owns a deterministic `DesertAtmosphere` node that maps all terrain surfaces to four biome profiles and draws a fixed 96-mark field without allocating particle nodes.[1] The new implementation upgrades that existing seam rather than introducing a second competing overlay. It retains the public profile and accessibility API, replaces generic colored streaks with biome-specific particle families, raises the fixed full-quality ceiling to **128 cosmetic marks**, and anchors the field to the active camera so weather remains visible throughout streamed-world travel.

The effect remains a procedural `Node2D` particle simulation. Particle positions, lifetimes, velocity variation, scale, rotation, and alpha are derived from stable integer seeds and elapsed time. There are no collision shapes, physics bodies, input handlers, gameplay mutations, or per-particle nodes. This preserves the project’s bounded-presentation architecture while still creating layered motion and material-specific silhouettes.

## Four-biome visual matrix

| Biome | Primary particles | Secondary particles | Motion identity | Palette |
|---|---|---|---|---|
| **Desert** | Fine sand streaks | Broad translucent gust ribbons and sparse grit | Fast lateral flow with shallow upward lift and breathing gust speed | Ochre, pale gold, warm cream |
| **Oasis Wetlands** | Diagonal rain streaks | Low drifting mist motes and small surface ripple rings | Gravity-led rainfall with restrained crosswind and slow near-ground haze | Blue-gray rain, muted teal, pale reed green |
| **Frozen Tundra** | Soft snow flakes | Ice grains and curved drift ribbons | Slow diagonal settling, lateral swirl, and periodic whiteout bands | White, ice cyan, slate blue |
| **Lava Fields** | Falling irregular ash flakes | Rising embers and sparse hot cinders | Downward ash tumble opposed by buoyant ember lift and heat-side drift | Charcoal, warm gray, ember orange, pale yellow |

Each profile uses three deterministic visual classes drawn from the same 128-slot budget. Full quality displays the complete budget, Reduced displays 65%, Minimal displays 35%, and `vfx_intensity` scales the selected quality count continuously to true zero. The existing VFX slider and effects-quality preference remain authoritative.[2]

## Weather-audio synchronization

The ambient weather controller already exposes normalized biome, smoothed intensity, target intensity, and bounded hazard activity.[3] It will register itself in the `weather_audio_layer` scene group. The atmosphere node discovers that source and uses its current biome and smoothed intensity as the visual authority. This means a stronger Glasswind Front produces denser and faster sand, an active Reedrain Veil produces heavier rainfall, Whiteout Drift thickens into broader snow bands, and Ashfall Breath introduces more ash and embers at the same moment the corresponding audio layer rises.

When the audio layer is unavailable—such as isolated tests or early scene construction—the atmosphere falls back to the terrain beneath the Walker and the profile’s base intensity. The fallback preserves existing behavior and prevents a presentation dependency from affecting gameplay startup.

## Viewport anchoring and transition behavior

The field computes its draw rectangle from the current camera position and viewport size on every redraw. Particles wrap within a padded viewport rectangle, so no weather gap appears during long-distance streaming. The node does not follow or modify the camera; it only converts the camera’s world-space center into a local draw region.

Biome changes use a **0.8-second visual blend**. The outgoing and incoming profiles split the same visible-mark budget according to transition progress, so a crossfade never doubles the particle count. All marks continue deterministic motion during the blend, avoiding both instant replacement and allocation spikes.

| Runtime bound | Contract |
|---|---:|
| Full-quality particle marks | 128 maximum |
| Reduced-quality multiplier | 0.65 |
| Minimal-quality multiplier | 0.35 |
| Biome blend | 0.8 seconds |
| Profile classes | 3 per biome |
| Collision or input | None |
| Particle nodes | None |
| Per-frame node allocation | None |

## Drawing contracts

Desert sand uses narrow lines for grains and larger translucent quads for gust ribbons. Wetland rain uses thin falling lines, mist uses low-alpha circles, and ripples use short expanding arcs. Frozen flakes use compact crossed strokes, ice grains use points, and whiteout bands use soft diagonal ribbons. Volcanic ash uses small rotated quadrilaterals, while embers use luminous circles with short rising tails. Every class uses stable phase offsets so repeated frames animate smoothly without relying on random-number calls.

The system remains above terrain and world objects at the existing atmosphere `z_index` while preserving HUD readability. Alpha ceilings are conservative, no particle draws a full-screen opaque layer, and the visual density responds to the same smoothed weather intensity that controls the ambient audio bed.

## Acceptance criteria

The implementation is complete when all four profiles have distinct deterministic particle-class counts and motion vectors; the total visible budget never exceeds 128; Reduced, Minimal, and zero-intensity accessibility settings scale correctly; camera movement changes the draw rectangle without changing simulation identity; biome changes blend without exceeding the cap; live weather-audio intensity drives particle density and speed; no particle owns collision, input, or gameplay state; and the synchronized `main` branch passes import, lint, contract tests, complete smoke validation, headless boot, and four-biome Xvfb visual certification.

## References

[1]: https://github.com/junnyboi/proto-isometric/blob/0ed77a5973591d6fe463458917c6055fc9e0d157/scripts/desert_atmosphere.gd "Existing deterministic atmosphere node"
[2]: https://github.com/junnyboi/proto-isometric/blob/0ed77a5973591d6fe463458917c6055fc9e0d157/scripts/player_preferences.gd "Effects-quality and VFX intensity preferences"
[3]: https://github.com/junnyboi/proto-isometric/blob/0ed77a5973591d6fe463458917c6055fc9e0d157/scripts/biome_weather_audio.gd "Biome weather audio metrics and hazard intensity"


## Windowed visual certification

The final Godot 4.7.2 Xvfb capture rendered the production particle controller at 1280×720 in all four profiles. Desert showed separate fast sand streaks, pale gust ribbons, and grit; Oasis Wetlands showed gravity-led rain, mist circles, and ripple arcs; Frozen Tundra showed crossed snowflakes, ice grains, and wide drift ribbons; Lava Fields showed irregular falling ash, rising orange embers, and cinder tails. A modest final alpha adjustment improved visibility while preserving transparent backgrounds and unobstructed labels. Every panel remained below the 128-mark ceiling at its live weather-audio intensity, and the windowed run completed without script errors, leaked nodes, or retained resources.
