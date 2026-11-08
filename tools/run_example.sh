#!/bin/bash
# Runs examples/minimal with the current addons/truss, in every mode, and checks the output.
# Usage: GODOT=/path/to/godot tools/run_example.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EX="$ROOT/examples/minimal"
GODOT_CMD="${GODOT:-godot}"
rm -rf "$EX/addons" && mkdir -p "$EX/addons" && cp -r "$ROOT/addons/truss" "$EX/addons/truss"
"$GODOT_CMD" --headless --path "$EX" --import > /dev/null 2>&1
fail=0

# check <mode> <expected exit code> <text that must appear>...
check() {
	local mode="$1" want="$2"
	shift 2
	local args=()
	[ -n "$mode" ] && args=(-- "--break=$mode")
	local out code ok=1
	out="$(timeout 60 "$GODOT_CMD" --headless --path "$EX" "${args[@]}" 2>&1)"
	code=$?
	[ "$code" = "$want" ] || ok=0
	for p in "$@"; do
		grep -qF -- "$p" <<<"$out" || { ok=0; echo "  missing: $p"; }
	done
	if [ $ok = 1 ]; then
		echo "PASS ${mode:-normal} (exit $code)"
	else
		echo "FAIL ${mode:-normal} (exit $code, expected $want)"
		echo "$out" | tail -15
		fail=1
	fi
}

check "" 0 "booted: CoreModule, StorageModule, ScoreModule" "label updated -> Score: 5" \
	"label updated -> Score: 15" "rejected -1: points must be positive, got -1" "final label: Score: 15"
check cycle 1 "BOOT FAILED [module_cycle]" "module dependency cycle: CycleA -> CycleB -> CycleA"
check missing-module 1 "BOOT FAILED [missing_dependency]" "ScoreModule depends on StorageModule, which was not added"
check missing-registration 1 "BOOT FAILED [invalid_container]" "Score is not registered" "ScoreStore is not registered"
exit $fail
