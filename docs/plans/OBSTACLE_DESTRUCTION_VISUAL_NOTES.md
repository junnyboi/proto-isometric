# Obstacle Destruction Visual Notes

**Author:** Manus AI
**Baseline:** `2c09eae901a0928dbe455cc82fdb0764d14eb01f`

## Existing obstacle art direction

The shipped generated destructibles use a centered three-quarter isometric prop presentation on a true transparent 256 × 256 canvas. The complete ground-contact silhouette fits comfortably inside the frame with no cast shadow, interface element, text, scenery, or detached decoration. Materials use crisp, compact shapes and readable value separation rather than noisy pixel-art abstraction.

The frozen snow rock is a low, broad cluster of irregular squared stone blocks with bright snow caps and small icy seams. The lava obsidian cluster uses a similarly low, broad footprint but differentiates itself with sharp black glass shards and restrained orange-red fissures. The new desert assets should retain this shared scale, camera angle, grounded footprint, transparency, and small-size readability while introducing warm eroded sandstone and iron-rich desert stone.

## Destruction behavior target

Obstacle world truth must change on the accepted Smash request, before the Walker contact animation completes: the obstacle disappears, its cell becomes walkable, haze and static-object rendering refresh, scrap is deposited, and persistence is updated immediately. The animation may continue as presentation, but it must not hold collision or obstacle visibility.

Biome debris is presentation-only. It uses nonblocking `RigidBody2D` fragments with collision layer and mask set to zero, deterministic outward launch velocities, gravity and angular velocity, material-specific shapes and palettes, and a hard one-second fade-and-recycle lifetime. Desert uses warm chipped stone; wetlands use damp wood splinters and moss-dark fragments; frozen terrain uses ice/stone or frost-pale wood shards; lava uses black basalt/obsidian fragments with restrained ember accents.

## GPT Image 2 master review

The Sunscoured Sandstone Cluster has a strong low stepped silhouette, readable warm upper planes, and clear rust seams. The Ironstone Knuckle is distinctly darker, denser, and more angular, with black mineral bands and a different block arrangement. Both masters are complete and well framed, but both retain long key-color streaks and edge fringe from transparent-background extraction. Those artifacts must be removed deterministically before runtime use. The accepted runtime derivatives will isolate the largest centered connected subject, decontaminate key-color edge pixels, crop to the visible bounds with padding, center on a transparent square canvas, and downsample to 256 × 256 RGBA.

## Runtime asset and debris implementation review

The cleaned 256 × 256 runtime derivatives retain complete silhouettes and remain distinct at the intended gameplay scale. The sandstone sprite reads as a bright stepped slab formation; the ironstone sprite reads as a darker, sharper, denser mound. The key-color streaks and edge fringe visible in both 1920-pixel masters are absent from the runtime preview. Godot 4.7.2 imports both sprites as RGBA8 textures.

Obstacle break effects now use pooled `RigidBody2D` fragments. The fragment renderer supports irregular stone, narrow wood splinter, diamond ice, and jagged volcanic silhouettes. The biome catalog controls each material family’s palette, launch-speed range, fragment-size range, angular-velocity range, gravity scale, and shape. Fragment collision layers and masks are zero, no collision shapes are created, and all active bodies fade and return to the pool at the one-second boundary.

## Final Xvfb certification

A 1280 × 720 Godot 4.7.2 Xvfb capture rendered both generated desert variants and four live pooled physics-debris bursts after 0.30 seconds of 2D physics simulation. The sandstone and ironstone silhouettes remain clean, centered, transparent, materially distinct, and readable at gameplay scale. Desert stone scatters as warm irregular chips; wetland wood uses narrow brown and moss-dark splinters; frozen debris uses bright diamond ice chips; volcanic debris uses dark jagged shards with restrained orange accents. The fragments show visible ballistic separation and rotation without opaque boxes or clipping. Automated lifecycle checks separately confirm every fragment has zero collision layer and mask, fades before the one-second boundary, and returns to the fixed pool at one second.
