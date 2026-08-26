# P6 Settler Asset Provenance

These sixteen runtime PNGs were authored for **Protos Harvest P6** with **GPT Image 2** on 2026-08-26. The eight portrait masters and eight static isometric world-sprite masters remain in the Manus project workspace; source masters are not shipped in the game repository or Web export.

The runtime candidates were produced by the deterministic Pillow/OpenCV pipeline `process_settlers.py`: chroma cleanup, largest connected-component isolation, alpha trim, resize, and lower-center anchoring. Portrait canvases are **320×400 RGBA**. Static world-sprite canvases are **256×384 RGBA**. These static sprites are deliberately not represented as P7 animation; future animation must use the approved locked-camera video-to-spritesheet workflow.

Representative visual QA accepted Amara Voss's portrait and Noor Haddad's world sprite. All runtime assets were then admitted through dimensions, alpha, checksum, Godot-import, and export-registration checks.

## Runtime SHA-256 manifest

| Runtime path | SHA-256 |
|---|---|
| `portraits/settler_amara_voss.png` | `d2bafbcad06c7b0f8a09122cea5e9df43c0f61d0b5b41880fe14258fadd6e7e6` |
| `portraits/settler_elena_moroz.png` | `370dcfd69009fbb02241a456554cfb9a553783fa63af101ff9f27c5860b994f3` |
| `portraits/settler_ishan_patel.png` | `2468bff8bcd2842bb0d8892cf98ed8c27b8f19a06b55228a6f046e2db32adf0c` |
| `portraits/settler_keiko_tan.png` | `948d27499a97dd3d955ec630ea3913e21a560fd037f98835a07e393576e62f19` |
| `portraits/settler_maeve_quinn.png` | `85a737475a0ec92238857aaa2bb85d38a822360aa4673eab34627f6e2d21d968` |
| `portraits/settler_malik_okafor.png` | `eabb6be2dcc41d3015622f0feb10e1ccb77c32a72b7a9fe361bd20a21249df87` |
| `portraits/settler_noor_haddad.png` | `01d62537a671beac75711c0ad5dee347ee819cda02a499282954f505fdc232f0` |
| `portraits/settler_tomas_reed.png` | `9f7494681c68df121fdb09febc744c83961c2fee4963c7626f46d2b91247ddac` |
| `sprites/settler_amara_voss.png` | `346fdd475515f99a7af7bf1bde733c6c2e30aa44251c6292b09009d4c795d6bd` |
| `sprites/settler_elena_moroz.png` | `d4caa61136d18e229b6fef41ba7be15b7cfef1e66bf1474ca692e30ae411b72a` |
| `sprites/settler_ishan_patel.png` | `8323536c095775298f1772098fef44248e3fcdb9d06662fa33e5b3dcd0d123d2` |
| `sprites/settler_keiko_tan.png` | `f2b26f1f5a20a46e3ab322274ac2b4bbd1c234c7fda8b817e94735b4cca55b9f` |
| `sprites/settler_maeve_quinn.png` | `01df8eb153369ebabf7f8b471bed87ec51eac4484ea2caae356c5a9ba18bc7d5` |
| `sprites/settler_malik_okafor.png` | `c09f52563fb0e96a1eca5c7d2557b535b29304be1b2388ae6273065a61392275` |
| `sprites/settler_noor_haddad.png` | `935f7fe03a00b54ae15c5881486fd5a94e4c7e6e967f592e22bcddf2d110e198` |
| `sprites/settler_tomas_reed.png` | `034d1ce2a78a8d7b16a51d37f61b7b3b43a468a0c744ae8a8184a0119567d140` |
