#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.venvs/godot-tools/bin:$HOME/bin:$PATH"
GODOT="${GODOT:-$HOME/bin/godot}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
WEB_OUT="${WEB_OUT:-/home/ubuntu/proto-isometric-build/web}"
MODE="${1:-}"
SCENARIO="title_launch"
if [[ "$MODE" == --scenario=* ]]; then
  SCENARIO="${MODE#--scenario=}"
  MODE="--scenario"
fi
cd "$ROOT"
rm -rf artifacts
mkdir -p "artifacts/$SCENARIO"
started="$(date +%s)"

printf '[L0] fresh import bootstrap\n'
timeout 30s "$GODOT" --headless --path . --import >/tmp/proto-isometric-import.log 2>&1
if grep -E 'ERROR:|SCRIPT ERROR:' /tmp/proto-isometric-import.log; then
  cat /tmp/proto-isometric-import.log >&2
  echo 'Blocking error in fresh import log' >&2
  exit 1
fi

printf '[L1] lint\n'
mapfile -d '' gd_files < <(find scripts selftest test -type f -name '*.gd' -print0 | sort -z)
((${#gd_files[@]} > 0))
gdlint "${gd_files[@]}"
for script in "${gd_files[@]}"; do
  timeout 20s "$GODOT" --headless --path . --check-only -s "$script" >/tmp/proto-isometric-check.log 2>&1 || {
    cat /tmp/proto-isometric-check.log >&2
    exit 1
  }
done

printf '[L2] GUT\n'
timeout 30s "$GODOT" --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit >artifacts/gut.log 2>&1
cat artifacts/gut.log
grep -Eq 'Tests[[:space:]]+[0-9]+|Passing[[:space:]]+[1-9]' artifacts/gut.log
grep -Eq 'Passing[[:space:]]+[1-9]|[1-9][0-9]* passed' artifacts/gut.log

printf '[L3b] boot\n'
timeout 20s "$GODOT" --headless --path . --quit-after 2 >artifacts/boot.log 2>&1
grep -F '[PROTO_ISOMETRIC_READY]' artifacts/boot.log
if grep -E 'ERROR:|SCRIPT ERROR:' artifacts/boot.log; then
  cat artifacts/boot.log >&2
  echo 'Blocking runtime error in boot log' >&2
  exit 1
fi

printf '[L4-headless] scenario=%s\n' "$SCENARIO"
timeout 20s "$GODOT" --headless --fixed-fps 60 --path . -s selftest/harness.gd -- \
  "--scenario=$SCENARIO" --seed=42 "--shots=res://artifacts/$SCENARIO" >artifacts/scenario-headless.log 2>&1
cat artifacts/scenario-headless.log
jq -e '.result == "PASS" and .completion_sentinel == true and (.checks | length > 0)' "artifacts/$SCENARIO/report.json" >/dev/null
grep -F '[SCENARIO_DONE]' artifacts/scenario-headless.log
if grep -E 'ERROR:|SCRIPT ERROR:' artifacts/scenario-headless.log; then
  echo 'Blocking runtime error in headless scenario log' >&2
  exit 1
fi

if [[ "$MODE" == "--full" ]]; then
  printf '[L4/L5-windowed] scenario=%s\n' "$SCENARIO"
  rm -rf "artifacts/$SCENARIO"
  mkdir -p "artifacts/$SCENARIO"
  windowed_started="$(date +%s)"
  timeout 25s xvfb-run -a "$GODOT" --audio-driver Dummy --path . --resolution 1280x720 -s selftest/harness.gd -- \
    "--scenario=$SCENARIO" --seed=42 "--shots=res://artifacts/$SCENARIO" >artifacts/scenario-windowed.log 2>&1
  cat artifacts/scenario-windowed.log
  jq -e '.result == "PASS" and .completion_sentinel == true and ([.shots[] | select(.status == "SKIP")] | length == 0)' "artifacts/$SCENARIO/report.json" >/dev/null
  if grep -E 'ERROR:|SCRIPT ERROR:' artifacts/scenario-windowed.log; then
    echo 'Blocking runtime error in windowed scenario log' >&2
    exit 1
  fi
  for shot in title_launch staging_field; do
    png="artifacts/$SCENARIO/$shot.png"
    test -s "$png"
    dims="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$png")"
    test "$dims" = "1280x720"
    ffmpeg -v error -xerror -i "$png" -f null -
  done
  report_mtime="$(stat -c %Y "artifacts/$SCENARIO/report.json")"
  title_mtime="$(stat -c %Y "artifacts/$SCENARIO/title_launch.png")"
  staging_mtime="$(stat -c %Y "artifacts/$SCENARIO/staging_field.png")"
  test "$title_mtime" -ge "$windowed_started"
  test "$staging_mtime" -ge "$windowed_started"
  test "$report_mtime" -ge "$title_mtime"
  test "$report_mtime" -ge "$staging_mtime"

  printf '[WEB] fresh export\n'
  rm -rf "$WEB_OUT"
  mkdir -p "$WEB_OUT"
  timeout 60s "$GODOT" --headless --path . --export-release Web "$WEB_OUT/proto-isometric.html" >artifacts/web-export.log 2>&1
  cat artifacts/web-export.log
  for ext in html js wasm pck; do
    test -s "$WEB_OUT/proto-isometric.$ext"
  done
  sha256sum "$WEB_OUT"/* | sort >artifacts/web-export.sha256
fi

finished="$(date +%s)"
source_hash="$(find project.godot export_presets.cfg data scenes scripts selftest test assets/audio -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)"
jq -n \
  --arg mode "${MODE:-standard}" \
  --arg scenario "$SCENARIO" \
  --arg source_hash "$source_hash" \
  --argjson seconds "$((finished - started))" \
  '{result:"PASS", mode:$mode, scenario:$scenario, source_hash:$source_hash, tests:"nonzero", completion_sentinel:true, seconds:$seconds}' \
  > artifacts/verify.json
printf '[VERIFY_PASS] mode=%s seconds=%s source_hash=%s\n' "${MODE:-standard}" "$((finished - started))" "$source_hash"
