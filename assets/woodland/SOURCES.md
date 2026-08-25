# Protos Harvest woodland runtime sources

The broadleaf tree, conifer tree, and pond were generated with **GPT Image 2** on 2026-08-25 after reviewing the repository's existing terrain, destructible, and ruin art. Runtime derivatives were cleaned with deterministic chroma-key processing, lower-center anchored for 2:1 isometric depth sorting, resized with Lanczos filtering, and visually inspected at gameplay scale.

| Runtime file | Dimensions | SHA-256 |
|---|---:|---|
| `woodland_broadleaf_tree.png` | 256×256 RGBA | `7f255ca51fd1820ec77c66d0559d0ef7e84014a449202ade43c97eca1ff21ced` |
| `woodland_conifer_tree.png` | 256×256 RGBA | `a2577c3d181ed82f083d1c8645f40295ffb383216468145c9fb9bddea44a46fb` |
| `woodland_pond.png` | 512×512 RGBA | `69de12a5035d1dca332b3c778f80054cbbe8daae4370f359de4b49b641ca4a11` |

The images are presentation only. The pure `WoodlandClearing` classifier owns tree/pond placement and variants, `InfiniteWorld` owns streamed obstacle state, and `WorldObjects` batches visible sprites without allocating one Node per tree.
