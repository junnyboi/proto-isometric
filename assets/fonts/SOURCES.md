# Runtime font source

The current runtime fallback is **ManusGameSC Common**; ManusCC0 remains primary. See the current compact-runtime record below. Earlier entries document superseded font versions.

## Historical UI-only subset

`NotoSansCJKsc-ProtoIsometric.otf` is a glyph-subset derivative of **Noto Sans CJK SC Medium** generated with fonttools `pyftsubset`. The subset corpus is the union of every key and rendered string in `data/locales/en.json` and `data/locales/zh-CN.json`, printable ASCII, and the Godot Web loading-shell product text. The frozen corpus contains **1,088 distinct codepoints** and is committed as `NotoSansCJKsc-ProtoIsometric.corpus.txt`.

The historical builder was `tools/build_runtime_font_subset.py` (now a wrapper around the compact-font guard). P11 verifies that every current locale codepoint exists in the runtime font's Unicode cmap, so Web rendering never depends on an unexported host-system fallback.

| Artifact | SHA-256 |
|---|---|
| Source `/usr/share/fonts/opentype/noto/NotoSansCJKsc-Medium.otf` | `ca094f6b0001fb048ca39ddd797a0cdb0179e1e55c6561e111c49c3e6a61d7b7` |
| Runtime `NotoSansCJKsc-ProtoIsometric.otf` | `c7ff6c5fa3fad37279dc29702b3164730eb834664e650614e5c373e40032000a` |

- Source: https://github.com/notofonts/noto-cjk
- Copyright: 2010–2012 Google Corporation
- License: SIL Open Font License 1.1; see `OFL.txt`.

## Historical full in-game Chinese face

`NotoSansCJKsc-ProtoIsometric.otf` previously retained the complete Noto Sans CJK SC Regular upstream bytes (SHA-256 `2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b`, 16,437,364 bytes). This 16 MB runtime version was superseded by the compact fallback below.

## Current compact common-Chinese runtime

`ManusGameSC-Common.woff2` supersedes the full face and earlier subsets. It is a 992,160-byte Noto Sans CJK SC derivative containing 6,547 codepoints, SHA-256 `150544e032d5a266d214799dbab5c6b6e9bad78645bdeaff5d11aba8cae43f7c`. The full source remains an authoring input only. See `cjk-font.json`, `cjk-codepoints.json`, and `NotoSansCJK-COPYRIGHT.txt`.
