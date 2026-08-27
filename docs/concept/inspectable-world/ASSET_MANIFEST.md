# Inspectable World Dossier Asset Manifest

The concept-recreation dossier uses **GPT Image 2** for every newly authored visual asset. The generation masters were created on 27 August 2026 outside the source repository with a temporary magenta carrier background. Runtime derivatives were produced only through deterministic chroma-key cleanup, edge-connected background removal, and Lanczos downscaling. No procedural drawing, stock art, or non-GPT visual generation was used.

## Runtime assets

| Asset | Runtime dimensions | Runtime bytes | SHA-256 | Purpose |
|---|---:|---:|---|---|
| `assets/ui/dossier/dossier_action_icons.png` | 1024×1024 | 693,196 | `d37b81c9a3ee57efd6b3693636c27d8159e76fedd6c1e9823e7660066962814a` | Sixteen 256×256 action pictograms in a 4×4 atlas. |
| `assets/ui/dossier/dossier_surface_thumbnails.png` | 768×768 | 926,787 | `b2846d2ed3f7e61b0bf2e271dad890ee4fe56e563c54329d9145727c0ae18f2f` | Nine 256×256 terrain/resource dioramas in a 3×3 atlas. |
| `assets/ui/dossier/dossier_object_portraits.png` | 768×768 | 892,184 | `a7e966db89959597eca50284013803c8c5435e041636534143aa88524502e737` | Nine 256×256 canonical object portraits in a 3×3 atlas. |

The runtime catalog `interaction_dossier_asset_catalog.gd` returns bounded `AtlasTexture` regions and never creates semantic state. It maps only canonical action presentation IDs and target subkinds to art. Unknown actions receive the neutral dossier icon; unknown object targets receive the generic canonical facility portrait.

## Source masters

| Master | Dimensions | SHA-256 |
|---|---:|---|
| `dossier_action_icons_raw.png` | 1920×1920 | `7280d799ec97fd2c5041a95387d28fc59e8afb40d96a5bcba0fb07c92cf5a0a4` |
| `dossier_surface_thumbnails_raw.png` | 1920×1920 | `64fd05112155a1431b96cec6a3d47b69e8e54e8e940c6da39388d1e5cae4a4cb` |
| `dossier_object_portraits_raw.png` | 1920×1920 | `53fdf99aafc005e203f407a0d1489aac147837d4e8ab793863d56347a2ac0441` |

The masters remain outside the source repository because only optimized runtime derivatives ship. Their hashes provide reproducibility and review continuity.

## Semantic cell maps

| Atlas | Row-major cells |
|---|---|
| Action icons | scan/inspect, till, plant, water; harvest, fish, repair/service, power; waypoint/ship, guide/open, neutral summary, history/sleep; lock/demolish, cost crate, back/move, activate/target. |
| Surface thumbnails | woodland grass, freshwater edge, tilled loam; mature crop, tree cluster, mineral deposit; salvage, ruined greenhouse, restored greenhouse. |
| Object portraits | damaged greenhouse terminal, damaged workshop, damaged clinic-kitchen; homestead, storage, repaired greenhouse; freshwater pond, mature tree, mineral deposit. |

## Prompt and truth constraints

The prompts required Protos Harvest’s post-collapse agricultural science-fiction material language, isometric three-quarter perspective, cyan/teal terminal accents, restrained amber highlights, no text, no HUD, and removable magenta backgrounds. Object generations were explicitly prohibited from depicting gauges, fault labels, blueprints, ownership, power networks, or other world state that is not guaranteed by the canonical interaction snapshot. Consequently, the art communicates identity while all mutable facts remain text projected from current authoritative state.
