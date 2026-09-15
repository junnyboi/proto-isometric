# Runtime font source

`NotoSansCJKsc-ProtoIsometric.otf` is a glyph-subset derivative of **Noto Sans CJK SC Medium** generated with fonttools `pyftsubset`. The subset corpus is the union of every key and rendered string in `data/locales/en.json` and `data/locales/zh-CN.json`, printable ASCII, and the Godot Web loading-shell product text. The frozen corpus contains **1,088 distinct codepoints** and is committed as `NotoSansCJKsc-ProtoIsometric.corpus.txt`.

The deterministic builder is `tools/build_runtime_font_subset.py`. P11 verifies that every current locale codepoint exists in the runtime font's Unicode cmap, so Web rendering never depends on an unexported host-system fallback.

| Artifact | SHA-256 |
|---|---|
| Source `/usr/share/fonts/opentype/noto/NotoSansCJKsc-Medium.otf` | `ca094f6b0001fb048ca39ddd797a0cdb0179e1e55c6561e111c49c3e6a61d7b7` |
| Runtime `NotoSansCJKsc-ProtoIsometric.otf` | `c7ff6c5fa3fad37279dc29702b3164730eb834664e650614e5c373e40032000a` |

- Source: https://github.com/notofonts/noto-cjk
- Copyright: 2010–2012 Google Corporation
- License: SIL Open Font License 1.1; see `OFL.txt`.

## Full in-game Chinese coverage

`NotoSansCJKsc-ProtoIsometric.otf` now retains the complete Noto Sans CJK SC Regular upstream bytes (SHA-256 `2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b`, 16,437,364 bytes). The filename is retained for existing resource references. See `NotoSansCJK-COPYRIGHT.txt` and `cjk-font.json`. The historical subset figures above record the previous version. Run `python3 tools/sync_cjk_font.py --check`; the legacy subset command delegates to this full-font installer.
