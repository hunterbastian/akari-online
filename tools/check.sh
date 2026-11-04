#!/bin/sh
# Pre-commit style check: lint, tests, then the bench if godot is available.
set -e
cd "$(dirname "$0")/.."
python3 tools/lint.py
GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
  if [ -x /tmp/godot/godot ]; then
    GODOT=/tmp/godot/godot
  else
    echo "godot not on PATH; lint passed, skipping runtime checks"
    exit 0
  fi
fi
"$GODOT" --headless --path . --script res://test/test_inventory.gd
"$GODOT" --headless --path . -- --state-test
"$GODOT" --headless --path . --script res://test/test_thrust_kick.gd
"$GODOT" --headless --path . --script res://test/test_cabin_terminal.gd
"$GODOT" --headless --path . --script res://test/test_cabin_bob.gd
"$GODOT" --headless --path . --script res://test/test_flight_readout.gd
"$GODOT" --headless --path . --script res://test/test_ship_log.gd
"$GODOT" --headless --path . --script res://test/test_time_command.gd
"$GODOT" --headless --path . --script res://test/test_orbit_pilot.gd
"$GODOT" --headless --path . --script res://test/test_ship_save.gd
"$GODOT" --headless --path . -- --stand-test
"$GODOT" --headless --path . --script res://test/test_sol_planet.gd
"$GODOT" --headless --path . --script res://test/test_planet_terrain.gd
if [ "${SKIP_BENCH:-}" = "1" ]; then
  exit 0
fi
# Draw calls need a real viewport. xvfb is used when DISPLAY is unset.
OUT=/tmp/akari-bench.out
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null 2>&1; then
  xvfb-run -a "$GODOT" --path . --audio-driver Dummy -- --bench > "$OUT"
else
  "$GODOT" --path . --audio-driver Dummy -- --bench > "$OUT"
fi
grep '^BENCH ' "$OUT" | tee tools/last_bench.txt
python3 tools/budget.py tools/last_bench.txt
