# Farming tool sprite sources

The hoe and watering action sheets use the approved **video-to-spritesheet** workflow. GPT Image 2 produced the locked-character anchor images; fixed-camera, zero-perspective-change chroma carriers generated the complete tool motions; deterministic extraction, background removal, alignment, and atlas packing produced 1024×512 RGBA runtime sheets. Production anchors and carriers remain in `/home/ubuntu/protos-harvest-assets/carriers/` and accepted processed derivatives remain in `/home/ubuntu/protos-harvest-assets/processed/`.

| Runtime file | Dimensions | SHA-256 |
|---|---:|---|
| `protos_hoe_spritesheet.png` | 1024×512 RGBA | `2926728a0d97ee77a7a2c63c5270bc1aeac1b955c0ed64653cccc1f9c408228c` |
| `protos_water_spritesheet.png` | 1024×512 RGBA | `cf89465ea091f6f333501180988b3e202bb834568915f251a006851969d06f9f` |
