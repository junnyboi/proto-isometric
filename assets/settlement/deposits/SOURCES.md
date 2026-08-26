# Stewardship Settlement Deposit Asset Sources

All shipped PNGs in this directory were generated with **GPT Image 2** specifically for Protos Harvest P5. They use a locked isometric camera, original Protos Harvest materials and silhouettes, and three state frames per source. No external game asset, name, or UI was copied.

| Runtime file | GPT Image 2 source | Deterministic processing | SHA-256 |
| --- | --- | --- | --- |
| `deposit_salvage_cluster_states.png` | `deposit_salvage_cluster_p5_clean.png` | Three equal source panels; hot-pink chroma removal; alpha cleanup; trim; proportional resize; lower-center 256×256 anchoring; 768×256 atlas packing | `d2bb436ce20ea8ae78f06925a8923cf94c25700310958a72cd3e331c90fa3d52` |
| `deposit_mineral_seam_states.png` | `deposit_mineral_seam_p5_clean.png` | Three equal source panels; hot-pink chroma removal; alpha cleanup; trim; proportional resize; lower-center 256×256 anchoring; 768×256 atlas packing | `918b14961a5d1e45af6fbacc7e69657a069243cab75c7a40840768625dc91f21` |
| `deposit_biomass_patch_states.png` | `deposit_biomass_patch_p5.png` | Three equal source panels; hot-pink chroma removal; alpha cleanup; trim; proportional resize; lower-center 256×256 anchoring; 768×256 atlas packing | `a3540c66665aaab69861dccd318a8547b46e71a89ff91b6d7ebde38da2ca2627` |

The initial alpha-background salvage and mineral generations were rejected because their generated transparency contained background artifacts. They were regenerated on a uniform `#FF00FF` carrier and processed by the deterministic Pillow pipeline retained outside the repository. Only the accepted optimized atlases ship here.
