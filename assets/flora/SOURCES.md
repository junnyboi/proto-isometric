# Protos Harvest flora asset sources

All five four-stage flora sheets were generated with **GPT Image 2** on 27 August 2026 for this repository. Prompts required exactly four isolated left-to-right growth stages, a 90 × 45 isometric game perspective, grounded photoreal botanical materials, bottom-centered anchors, no text, no UI, and transparent output. Existing `crop_starbloom_stages.png` and `woodland_broadleaf_tree.png` were supplied as style and perspective references.

The 2560 × 1440 generation outputs were processed deterministically into 1024 × 256 RGBA runtime atlases. Processing removed magenta-key spill, split the canvas into four stage regions, preserved common scale progression, bottom-aligned the specimens, removed disconnected cross-frame fragments, and emitted one optimized PNG. The original generation canvases are intentionally excluded from the source repository; the optimized runtime derivatives are the canonical shipped assets.

| Runtime asset | SHA-256 | Gameplay use |
|---|---|---|
| `flora_starflower_stages.png` | `66d52111a70ee7976f4500d8febc80aa629574f55acba1564b514a91c77c236b` | Wild mature Starflower and four cultivated stages |
| `flora_brambleberry_stages.png` | `f0f25ef5f57e9e753776de7ade74580562342610c020279158402cec580bac27` | Wild mature Brambleberry and four cultivated stages |
| `flora_sunpear_stages.png` | `795bf747e4d03e36696a6d158f56bce3649ce6636df6bd864131b9b600fbf877` | Wild mature compact Sunpear and four orchard stages |
| `flora_wildwheat_stages.png` | `63fbb77a22dad8cafc5c38d1ed156604b27bc272e5f7a4a70e5702b57b3c7695` | Wild mature wheat and four cultivated stages |
| `flora_cotton_stages.png` | `3d4d41b74d79ca6ba2a07262022a0f35409d415adcbc2cfb6ef4cb0901aea204` | Wild mature cotton and four cultivated stages |
| `wild_starflower_mature.png` | `4799f59764d5ccfd56f7d6de9a3f0fe7322b840d3f13c7f81bab92810523e896` | Dedicated mature Starflower draw source |
| `wild_brambleberry_mature.png` | `053c172d8e92a8979eb6fa98e297098c80d6eb7a15c11ba0a7b1ddc1c379825e` | Dedicated mature Brambleberry draw source |
| `wild_sunpear_mature.png` | `052300b54e574d7e10d3cac6ce091ad98cb63173a9b0dd436c7e187c225cb240` | Dedicated mature Sunpear draw source |
| `wild_wildwheat_mature.png` | `c1f935419cdbbf137166a5018cc122e251ebf039071a135df68d82e9fa12a4c5` | Dedicated mature Wildwheat draw source |
| `wild_cotton_mature.png` | `e1d0a1ed5ddbb1fb4daaa33998a759e76743971b69c45567c87cc4b1df3dc02a` | Dedicated mature Cotton draw source |

The five `wild_*_mature.png` files are exact 256 × 256 crops of the mature atlas frames. The runtime reconstructs them as cached RGBA `ImageTexture` objects before CanvasItem drawing to preserve alpha consistently across native and Web backends. The assets are original project media and contain no third-party logos, typography, or extracted commercial-game content.
