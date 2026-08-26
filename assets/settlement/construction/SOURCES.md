# Stewardship Settlement Construction Asset Sources

All PNGs in this directory are **GPT Image 2** runtime assets created for the Protos Harvest Stewardship Settlement expansion. Source masters remain outside the source repository in the Manus project working set. The committed files are deterministic, alpha-cleaned runtime derivatives produced by `/home/ubuntu/protos-harvest-settlement-overhaul/assets/process_runtime_assets.py`; no procedural replacement artwork is used.

| Runtime asset | GPT Image 2 source master | Source SHA-256 | Runtime SHA-256 |
| --- | --- | --- | --- |
| `building_shelter_pod.png` | `building_shelter_pod.png` | `d996f39ad9b7026d699278ef992fdca7db7fda30b714b8e1577e560d3ee253e5` | `df2cb524d7f898aa3d94c92ee66ae00b3f949d977feee2cef3b46b32bc93a839` |
| `building_field_warehouse.png` | `building_field_warehouse.png` | `e4f59279b0c96f6c51e51cf740bb15c374657ea15deb62c68a526327f95c95f6` | `7657421b096c3797a164e9bc837912b3385c9acc0758755e9c01db14936e9608` |
| `building_salvage_camp.png` | `building_salvage_camp.png` | `b88f3ba1ebfbf49e75474632b55e36d0c6d80b678578bccb879b412df47ceb93` | `0e20a7eb8cf91290d9b2c359200f504c103c9d15223e3eaef99851e9fedc3f6d` |
| `building_survey_drill.png` | `building_survey_drill.png` | `4eefec6f3f2c311734bc509d00e9640834619f9fcb4e0294f3c3cf843d5dcc1f` | `52aadbd397ab35e26c6de26bf5f5f30008847806071f2becc4b74af81a94beaa` |
| `building_coppice_station.png` | `building_coppice_station.png` | `8f7d48e463b3e24ca7adcb4205d2a21ed97151ed10b6e49c0d52c48ac682899c` | `97443d4a6ed8b5d8af8f75210db550fcf2c44ae1ade1b6a2bf8b7f95c1ef24d6` |
| `building_fabricator_annex.png` | `building_fabricator_annex.png` | `633a7c70f470cef6f0fc602b2208225412c06be7cd5676562aa3bfabc7a75c6e` | `0f6e73482c4bb056ed954aeb1337a6785a912c75824797782302e12d299cd1fc` |
| `building_fishing_platform.png` | `building_fishing_platform.png` | `c321055348abb9069dccae46daf4012ff101166769d826bb7f56f5baa8ecf135` | `20f4486d66ae9917cddd4cc22327c33506411d5e73dc06dbc32e66b653c75688` |
| `construction_scaffold_small.png` | `construction_scaffold_small.png` | `669e87fc3c2e4d0002d0deacb60e2932a8fd597ca2272a083be6ddfc4d26f7e8` | `2e6a74c6aca1da56e8cd7bad88418d4b79572d2c2fcf11b3d62fcccf25fff9da` |
| `construction_scaffold_large.png` | `construction_scaffold_large.png` | `71195f46e3285801c59d016ef3894bccca5de31c6fd1a01ef8117178dbf54e98` | `72f340a571e62bc3cbff3184c4ab3573864e0ad07cc176796425f3864a73d54b` |
| `icon_build_blueprint.png` | cells extracted from `ui_settlement_icons.png` | `098a38f6a0b38cf8d8e21e7712103676a77a56c494175f1cd9ffb2a52159967b` | `2fff0f27a2f923ccdec50e090858c52ed171f99455e3ad8a727b09205ffe5be1` |
| `icon_rotate_building.png` | cells extracted from `ui_settlement_icons.png` | `098a38f6a0b38cf8d8e21e7712103676a77a56c494175f1cd9ffb2a52159967b` | `3404cbc0315d4bc51e13082f248e310eec619940314508ce015a8d32d1d93cd4` |

The runtime pipeline applies hardened hot-pink chroma removal, trims transparent bounds, preserves all original generated visual content, and lower-center anchors building/scaffold props on 512×512 transparent canvases. The two UI icons are center-contained on 128×128 transparent canvases. Final acceptance remains contingent on Godot import, Xvfb gameplay-scale inspection, and Web export inclusion.
