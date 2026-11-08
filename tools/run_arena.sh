#!/bin/bash
# Runs the arena example in autoplay mode and checks the result, then runs arch_check on it.
# Usage: GODOT=/path/to/godot tools/run_arena.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EX="$ROOT/examples/arena"
G="${GODOT:-godot}"
rm -rf "$EX/addons" && mkdir -p "$EX/addons" && cp -r "$ROOT/addons/truss" "$EX/addons/truss"
"$G" --headless --path "$EX" --import > /dev/null 2>&1
fail=0

out="$(timeout 120 "$G" --headless --path "$EX" --fixed-fps 60 -- --autoplay 2>&1)"; code=$?
ok=1
for p in "wave 1 enemies:" "wave 1 cleared" "wave 2 cleared" "wave 3 cleared" "GAME OVER waves=3 score=180"; do
	grep -qF -- "$p" <<<"$out" || { ok=0; echo "  missing: $p"; }
done
if grep -qE "SCRIPT ERROR|Parse Error|^ERROR" <<<"$out"; then ok=0; echo "  errors in output:"; grep -E "SCRIPT ERROR|Parse Error|^ERROR" <<<"$out" | head -10; fi
if [ $code = 0 ] && [ $ok = 1 ]; then echo "PASS arena autoplay ($(grep -o 'GAME OVER.*' <<<"$out"))"; else echo "FAIL arena autoplay (exit $code)"; echo "$out" | tail -20; fail=1; fi

# More runs must find the record from the first one and not save again. Enemy directions depend on instance
# ids, so every run is a little different: several runs catch waves that can't be finished.
for run in 2 3 4; do
	out="$(timeout 120 "$G" --headless --path "$EX" --fixed-fps 60 -- --autoplay 2>&1)"; code=$?
	if [ $code = 0 ] && grep -qF "GAME OVER waves=3 score=180 record_saved=false" <<<"$out"; then
		echo "PASS run $run finishes and keeps the saved record"
	else
		echo "FAIL run $run (exit $code)"; echo "$out" | tail -10; fail=1
	fi
done

[ -f "$EX/architecture.cfg" ] || "$G" --headless --path "$EX" -s res://addons/truss/tooling/arch_check.gd -- --write-default-config > /dev/null 2>&1
out="$(timeout 60 "$G" --headless --path "$EX" -s res://addons/truss/tooling/arch_check.gd 2>&1)"; code=$?
if [ $code = 0 ]; then echo "PASS arena arch_check ($(grep -o 'arch_check: .*' <<<"$out"))"; else echo "FAIL arena arch_check (exit $code)"; grep VIOLATION <<<"$out"; fail=1; fi
exit $fail
