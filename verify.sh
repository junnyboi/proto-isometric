#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.venvs/godot-tools/bin:$HOME/bin:$PATH"
GODOT="${GODOT:-$HOME/bin/godot}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
WEB_OUT="${WEB_OUT:-/home/ubuntu/proto-isometric-build/web}"
MODE="${1:-}"

if [[ -n "$MODE" && "$MODE" != "--release" ]]; then
  echo "Usage: ./verify.sh [--release]" >&2
  exit 2
fi

cd "$ROOT"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/user-data"

printf '[1/5] import\n'
timeout 30s "$GODOT" --headless --path . --import >"$tmp/import.log" 2>&1
if grep -E 'ERROR:|SCRIPT ERROR:' "$tmp/import.log"; then
  cat "$tmp/import.log" >&2
  exit 1
fi

printf '[2/5] lint + runtime asset integrity + BGM loop gate\n'
mapfile -d '' gd_files < <(find scripts test -type f -name '*.gd' -print0 | sort -z)
((${#gd_files[@]} > 0))
gdlint "${gd_files[@]}"
/usr/bin/python3 tools/verify_gdscript_budgets.py
/usr/bin/python3 tools/verify_runtime_asset_integrity.py
python3 test/test_bgm_loops.py \
  --godot "$GODOT" \
  --json-report "$tmp/bgm-loops.json"

printf '[3/5] smoke\n'
timeout 180s env XDG_DATA_HOME="$tmp/user-data" "$GODOT" \
  --headless --path . -s test/smoke.gd >"$tmp/smoke.log" 2>&1
cat "$tmp/smoke.log"
grep -F '[SMOKE_PASS]' "$tmp/smoke.log" >/dev/null
if grep -E 'ERROR:|SCRIPT ERROR:' "$tmp/smoke.log"; then
  exit 1
fi

printf '[4/5] P11 golden 1,000-day schedule\n'
timeout 240s env XDG_DATA_HOME="$tmp/user-data" "$GODOT" \
  --headless --path . -s test/harvest_settlement_phase_eleven_runner.gd -- \
  --p11-days=1000 --p11-run-id=verify >"$tmp/p11.log" 2>&1
cat "$tmp/p11.log"
grep -F '[P11_SCHEDULE_HASH] run=verify days=1000 hash=162fc7dec14149a3ea7beb67007b8be8cc474a310ecd87cacee19061b4f37270 bytes=15933' \
  "$tmp/p11.log" >/dev/null
grep -F '[P11_CERTIFICATION_PASS] run=verify days=1000' "$tmp/p11.log" >/dev/null
if grep -E 'ERROR:|SCRIPT ERROR:|P11_CERTIFICATION_FAIL' "$tmp/p11.log"; then
  exit 1
fi

printf '[5/5] boot\n'
timeout 20s "$GODOT" --headless --path . --quit-after 2 >"$tmp/boot.log" 2>&1
grep -F '[PROTO_ISOMETRIC_READY]' "$tmp/boot.log" >/dev/null
grep -F '[TITLE_MUSIC_READY]' "$tmp/boot.log" >/dev/null
if grep -E 'ERROR:|SCRIPT ERROR:' "$tmp/boot.log"; then
  cat "$tmp/boot.log" >&2
  exit 1
fi

if [[ "$MODE" == "--release" ]]; then
  printf '[release] Web export\n'
  rm -rf "$WEB_OUT"
  mkdir -p "$WEB_OUT"
  timeout 60s "$GODOT" --headless --path . --export-release Web "$WEB_OUT/proto-isometric.html" >"$tmp/export.log" 2>&1
  cat "$tmp/export.log"
  if grep -E 'ERROR:|SCRIPT ERROR:' "$tmp/export.log"; then
    exit 1
  fi
  if grep -E 'Storing File: res://(addons|test|provenance|artifacts)/' "$tmp/export.log"; then
    echo 'Non-shipping files entered the Web export' >&2
    exit 1
  fi
  python3 tools/prepare_web_shell.py \
    --html "$WEB_OUT/proto-isometric.html" \
    --desktop-source assets/title/protos_harvest_title_desktop.png \
    --mobile-source assets/title/protos_harvest_title_mobile.png
  for ext in html js wasm pck; do
    test -s "$WEB_OUT/proto-isometric.$ext"
  done
  for loader in \
    proto-isometric.loader-desktop.webp \
    proto-isometric.loader-mobile.webp; do
    test -s "$WEB_OUT/$loader"
  done
  grep -F 'proto-isometric.loader-desktop.webp' "$WEB_OUT/proto-isometric.html" >/dev/null
  grep -F 'proto-isometric.loader-mobile.webp' "$WEB_OUT/proto-isometric.html" >/dev/null
  grep -F 'Restoring the clearing' "$WEB_OUT/proto-isometric.html" >/dev/null
  grep -F '#status-progress' "$WEB_OUT/proto-isometric.html" >/dev/null
  if grep -F 'src="proto-isometric.png"' "$WEB_OUT/proto-isometric.html"; then
    echo 'Generic Godot Web splash survived postprocessing' >&2
    exit 1
  fi
  printf '[release] exported PCK boot\n'
  (
    cd "$tmp"
    timeout 30s env XDG_DATA_HOME="$tmp/user-data" "$GODOT" \
      --headless \
      --main-pack "$WEB_OUT/proto-isometric.pck" \
      -s "$ROOT/test/exported_pack_boot.gd" \
      >"$tmp/pck-boot.log" 2>&1
  )
  cat "$tmp/pck-boot.log"
  grep -F '[PCK_BOOT_PASS]' "$tmp/pck-boot.log" >/dev/null
  if grep -E 'ERROR:|SCRIPT ERROR:|Parse Error' "$tmp/pck-boot.log"; then
    exit 1
  fi
fi

printf '[PASS] Protos Harvest%s\n' "${MODE:+ $MODE}"
