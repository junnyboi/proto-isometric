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

printf '[1/4] import\n'
timeout 30s "$GODOT" --headless --path . --import >"$tmp/import.log" 2>&1
if grep -E 'ERROR:|SCRIPT ERROR:' "$tmp/import.log"; then
  cat "$tmp/import.log" >&2
  exit 1
fi

printf '[2/4] lint + BGM loop gate\n'
mapfile -d '' gd_files < <(find scripts test -type f -name '*.gd' -print0 | sort -z)
((${#gd_files[@]} > 0))
gdlint "${gd_files[@]}"
python3 test/test_bgm_loops.py \
  --godot "$GODOT" \
  --json-report "$tmp/bgm-loops.json"

printf '[3/4] smoke\n'
timeout 30s env XDG_DATA_HOME="$tmp/user-data" "$GODOT" \
  --headless --path . -s test/smoke.gd >"$tmp/smoke.log" 2>&1
cat "$tmp/smoke.log"
grep -F '[SMOKE_PASS]' "$tmp/smoke.log" >/dev/null
if grep -E 'ERROR:|SCRIPT ERROR:' "$tmp/smoke.log"; then
  exit 1
fi

printf '[4/4] boot\n'
timeout 20s "$GODOT" --headless --path . --quit-after 2 >"$tmp/boot.log" 2>&1
grep -F '[PROTO_ISOMETRIC_READY]' "$tmp/boot.log" >/dev/null
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
  for ext in html js wasm pck; do
    test -s "$WEB_OUT/proto-isometric.$ext"
  done
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
