# P10 Seasonal Systems Asset Provenance

These P10 runtime PNGs were authored with **GPT Image 2** on 2026-08-26 for Protos Harvest. They follow the existing compact isometric/post-collapse farm art direction and use static growth stages only; no animated sprite claim is made.

The source masters were generated on hot-magenta backgrounds and processed outside the source repository by `assets/p10/process_assets.py` in the external settlement evidence bundle. The deterministic Pillow/OpenCV pipeline keys magenta, keeps the intended connected component, trims alpha, resizes with Lanczos, and lower-centers each subject. Tree stages use authored nonlinear source boundaries before packing into 1024×320 atlases. Fish and item icons are normalized to 320×192 and 192×192 transparent canvases.

| Runtime file | Purpose | Runtime SHA-256 |
|---|---|---|
| `orchard/tree_ironbark_stages.png` | Four-stage Ironbark growth atlas | `381f91f1a2d93b4250df0b56cd7b602fc1049132f0383ffc70359a46b5ef44bb` |
| `orchard/tree_cinderapple_stages.png` | Four-stage Cinderapple growth atlas | `cc06ca0645c3cf6578edc70ab277a26b9d86a2e6a78789f0acec08b4cadc4718` |
| `../fishing/fish_relay_minnow.png` | Relay Minnow catch icon | `c677b51a70069964b49b20430d6c2162ba2fe1f76c376fbb4608347bfe50dabc` |
| `../fishing/fish_rustfin_perch.png` | Rustfin Perch catch icon | `acecd8dc48c1d3f12864fd26d1a75b74e0fff4362cc75aa1c0e36f482384fbd3` |
| `../fishing/fish_glasslamp_eel.png` | Glasslamp Eel catch icon | `d0138813beb5934ee82d0b359c66a91283f3b907b4fb109cd38a3e43e5e2ca42` |
| `../fishing/fish_mossback_carp.png` | Mossback Carp catch icon | `77f88299e0f620485b22f66eb61966446bbb5cb244bf1917037fea63a8c56e35` |
| `../ui/items/item_ironbark_sapling.png` | Ironbark sapling inventory icon | `f46ed5a33a8950bc106ab2a569ccc70e13eb47d0fbae1a5a714be00f394a4c84` |
| `../ui/items/item_cinderapple_sapling.png` | Cinderapple sapling inventory icon | `66a84bd6b94281d3dfe904dcaf3694e6566662ae53d92d7d0009da3cdee9b3bd` |
| `../ui/items/item_fishing_rod.png` | Fishing rod inventory icon | `28d38dc06e0ccb23f96342090e73b77afeb2aad4aea023ee2d9f9c2b552375f5` |
| `../ui/items/item_luminous_bait.png` | Luminous bait inventory icon | `93df3ed0fefaf6e2f5475ceb4a108c5d21a769dd645f127e11573cfc87f7a5c7` |

Source-master SHA-256 values: Ironbark `2a74a6fc925af61cd32ac0003ef453413521201dadca831e27a05f624390abe0`; Cinderapple `92e347adc103f103afbb9f62cbdade55ccfd85be7f32e6115c533d0a881b4c25`; fish sheet `fede0b9dbcf6d5c13452cb4c8d1c29fe7e911dcbdcf23d69254d75d053443f90`; fishing item sheet `791c2c2240bd76a883ec9e77cad24185e7b58f08dc1e1ec7340dad97d1adec61`.
