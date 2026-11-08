#!/bin/bash
# End-to-end test of addons/truss/tooling in a throwaway project: strict profile, generators, arch_check.
# Usage: GODOT=/path/to/godot tools/test_tooling.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="${GODOT:-godot}"
P="$(mktemp -d)"
trap 'rm -rf "$P"' EXIT
fail=0
pass() { echo "PASS $1"; }
bad() { echo "FAIL $1"; [ -n "${2:-}" ] && echo "$2" | tail -20; fail=1; }

mkdir -p "$P/addons"
cp -r "$ROOT/addons/truss" "$P/addons/truss"
cat > "$P/project.godot" <<'EOF'
config_version=5

[application]

config/name="truss-tooling-test"
config/features=PackedStringArray("4.5")
EOF
run() { timeout 120 "$G" --headless --path "$P" "$@" 2>&1; }
tool() { local script="$1"; shift; run -s "res://addons/truss/tooling/$script" -- "$@"; }

# --- strict profile -------------------------------------------------------
out="$(tool strict_profile.gd)"; code=$?
[ $code = 1 ] && grep -q "would set   debug/gdscript/warnings/untyped_declaration" <<<"$out" && pass "strict_profile dry run lists changes" || bad "strict_profile dry run (exit $code)" "$out"
out="$(tool strict_profile.gd --apply)"; code=$?
[ $code = 0 ] && grep -q "untyped_declaration=2" "$P/project.godot" && pass "strict_profile --apply writes project.godot" || bad "strict_profile --apply (exit $code)" "$out"
out="$(tool strict_profile.gd)"; code=$?
[ $code = 0 ] && grep -q "already uses the profile" <<<"$out" && pass "strict_profile is idempotent" || bad "strict_profile second run (exit $code)" "$out"
out="$(tool strict_profile.gd --include-addons)"; code=$?
[ $code = 1 ] && grep -qE "directory_rules: res://addons -> 1|exclude_addons: true -> false" <<<"$out" \
	&& pass "strict_profile --include-addons uses the version's setting" || bad "strict_profile --include-addons (exit $code)" "$out"

# --- generators -----------------------------------------------------------
gen_ok=1
for args in "module inventory" "usecase inventory AddItem" "port inventory InventoryStore" "event inventory ItemAdded" "event inventory ItemRemoved item_id:StringName amount:int" "module shop"; do
	out="$(tool generate.gd $args)"; code=$?
	[ $code = 0 ] || { gen_ok=0; bad "generate $args (exit $code)" "$out"; }
done
[ $gen_ok = 1 ] && pass "generators create module, usecase, port, event"
out="$(tool generate.gd usecase inventory AddItem)"; code=$?
[ $code = 1 ] && grep -q "already exists" <<<"$out" && pass "generator refuses to overwrite" || bad "generator overwrite check (exit $code)" "$out"
out="$(tool generate.gd usecase)"; code=$?
[ $code = 2 ] && pass "generator usage error" || bad "generator usage (exit $code)" "$out"
out="$(tool generate.gd event inventory Broken amount)"; code=$?
[ $code = 2 ] && grep -q "name:Type" <<<"$out" && pass "generator rejects malformed event fields" || bad "generator event field check (exit $code)" "$out"
for f in features/inventory/inventory_module.gd features/inventory/application/add_item_request.gd \
	features/inventory/application/add_item_handler.gd features/inventory/application/ports/inventory_store.gd \
	features/inventory/infrastructure/memory_inventory_store.gd features/inventory/application/events/item_added.gd; do
	[ -f "$P/$f" ] || bad "missing generated file $f"
done

# --- generated code compiles under the strict profile ----------------------
cat > "$P/compile.gd" <<'EOF'
extends SceneTree
func _initialize() -> void:
	var failures: int = 0
	for path: String in ["res://features/inventory/inventory_module.gd", "res://features/inventory/application/add_item_request.gd",
			"res://features/inventory/application/add_item_handler.gd", "res://features/inventory/application/ports/inventory_store.gd",
			"res://features/inventory/infrastructure/memory_inventory_store.gd", "res://features/inventory/application/events/item_added.gd",
			"res://features/inventory/application/events/item_removed.gd", "res://features/shop/shop_module.gd"]:
		var s: Script = load(path)
		if s == null or not (s.can_instantiate() or (s as GDScript).is_abstract()):
			printerr("FAILED ", path)
			failures += 1
	var handler: TrRequestHandler = (load("res://features/inventory/application/add_item_handler.gd") as GDScript).new()
	var request: TrRequest = (load("res://features/inventory/application/add_item_request.gd") as GDScript).new()
	print("handles=", TrContracts.describe(handler.handles()), " result=", handler.handle(request))
	var removed: TrEvent = (load("res://features/inventory/application/events/item_removed.gd") as GDScript).new(&"potion", 2)
	print("event=", removed.get(&"item_id"), "x", removed.get(&"amount"))
	quit(1 if failures > 0 else 0)
EOF
run --import > /dev/null
out="$(run -s res://compile.gd)"; code=$?
[ $code = 0 ] && grep -q "handles=AddItemRequest result=TrResult.failure(not_implemented" <<<"$out" && grep -q "event=potionx2" <<<"$out" && pass "generated code compiles and runs (strict)" || bad "generated code (exit $code)" "$out"
rm "$P/compile.gd"

# --- arch_check -----------------------------------------------------------
out="$(tool arch_check.gd)"; code=$?
[ $code = 2 ] && grep -q "write-default-config" <<<"$out" && pass "arch_check without config explains how to create one" || bad "arch_check no config (exit $code)" "$out"
out="$(tool arch_check.gd --write-default-config)"; code=$?
[ $code = 0 ] && [ -f "$P/architecture.cfg" ] && pass "arch_check writes the default config" || bad "write config (exit $code)" "$out"
out="$(tool arch_check.gd --write-default-config)"; code=$?
[ $code = 2 ] && pass "arch_check does not overwrite the config" || bad "config overwrite (exit $code)" "$out"
out="$(tool arch_check.gd)"; code=$?
[ $code = 0 ] && grep -q "0 violations" <<<"$out" && pass "generated project has no violations" || bad "clean arch_check (exit $code)" "$out"

mkdir -p "$P/features/inventory/domain" "$P/features/shop/infrastructure" "$P/features/shop/application"
cat > "$P/features/inventory/domain/stock.gd" <<'EOF'
class_name Stock
extends RefCounted
var store: MemoryInventoryStore
var container: TrServiceContainer
EOF
cat > "$P/features/shop/infrastructure/shop_store.gd" <<'EOF'
class_name ShopStore
extends RefCounted
var other: MemoryInventoryStore
EOF
cat > "$P/features/shop/application/buy.gd" <<'EOF'
class_name Buy
extends RefCounted
var stock: Stock
var request: AddItemRequest
EOF
run --import > /dev/null
out="$(tool arch_check.gd --junit=res://reports/arch.xml)"; code=$?
expect=(
	"features/inventory/domain/stock.gd [domain] depends on MemoryInventoryStore"
	"features/inventory/domain/stock.gd [domain] uses TrServiceContainer, which is forbidden in this layer"
	"features/shop/infrastructure/shop_store.gd [infrastructure] reaches into feature inventory's infrastructure"
	"3 violations"
)
ok=1
for e in "${expect[@]}"; do grep -qF -- "$e" <<<"$out" || { ok=0; echo "  missing: $e"; }; done
grep -q "features/shop/application/buy.gd" <<<"$out" && { ok=0; echo "  unexpected violation for buy.gd (public layers)"; }
[ $code = 1 ] && [ $ok = 1 ] && pass "arch_check finds layer, forbidden-class and cross-feature violations" || bad "arch_check violations (exit $code)" "$out"
[ -f "$P/reports/arch.xml" ] && grep -q 'failures="2"' "$P/reports/arch.xml" && grep -q "forbidden in this layer" "$P/reports/arch.xml" \
	&& pass "arch_check writes a JUnit report" || bad "JUnit report" "$(cat "$P/reports/arch.xml" 2>/dev/null)"

# --- stateful_resources rule ---------------------------------------------------
cat > "$P/features/inventory/domain/item_def.gd" <<'EOF2'
class_name ItemDef
extends Resource
@export var id: StringName
@export_storage var stored_level: int = 0
var uses: int = 0
var _cooldown: float = 0.0
static var counter: int = 0
const MAX: int = 3
EOF2
cat > "$P/features/inventory/domain/weapon_def.gd" <<'EOF2'
class_name WeaponDef
extends ItemDef
@export var damage: int = 1
EOF2
run --import > /dev/null
out="$(tool arch_check.gd)"; code=$?
grep -q "item_def.gd" <<<"$out" && { echo "FAIL stateful_resources should be off by default"; fail=1; } || echo "PASS stateful_resources is off by default"
sed -i 's/^stateful_resources=\[\]/stateful_resources=["domain"]/' "$P/architecture.cfg"
out="$(tool arch_check.gd)"; code=$?
if grep -qF "item_def.gd [domain] Resource keeps runtime state in non-exported fields (uses, _cooldown)" <<<"$out" && ! grep -q "weapon_def.gd" <<<"$out"; then
	echo "PASS stateful_resources reports only fields declared in the script, not exported/stored/static/const ones"
else
	echo "FAIL stateful_resources"; echo "$out" | grep -E "VIOLATION|arch_check"; fail=1
fi

exit $fail
