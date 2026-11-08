#!/bin/bash
# Exports a throwaway project with --export-pack (no export templates needed) and runs the .pck, to check that
# TrRegistry finds content in an exported build while a naive DirAccess ".tres" filter finds nothing.
# Usage: GODOT=/path/to/godot tools/test_export.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="${GODOT:-godot}"
P="$(mktemp -d)"
RUN="$(mktemp -d)"
trap 'rm -rf "$P" "$RUN"' EXIT
mkdir -p "$P/addons" "$P/data/sub" "$P/build"
cp -r "$ROOT/addons/truss" "$P/addons/truss"
touch "$P/build/.gdignore"
cat > "$P/project.godot" <<'EOF'
config_version=5

[application]

config/name="truss-export-test"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.5")
EOF
printf 'class_name ItemDef\nextends Resource\n\n@export var id: StringName\n' > "$P/item_def.gd"
for n in potion elixir sub/sword; do
	printf '[gd_resource type="Resource" script_class="ItemDef" format=3]\n\n[ext_resource type="Script" path="res://item_def.gd" id="1_a"]\n\n[resource]\nscript = ExtResource("1_a")\nid = &"%s"\n' "$(basename "$n")" > "$P/data/$n.tres"
done
cat > "$P/main.gd" <<'EOF'
extends Node


func _ready() -> void:
	var naive: int = 0
	for f: String in DirAccess.get_files_at("res://data"):
		if f.ends_with(".tres"):
			naive += 1
	var reg := TrRegistry.new(ItemDef)
	var r: TrResult = reg.scan("res://data")
	print("naive_dir_access=%d registry_ok=%s registry=%d ids=%s" % [naive, r.ok, reg.size(), ",".join(PackedStringArray(reg.ids()))])
	get_tree().quit()
EOF
printf '[gd_scene format=3]\n\n[ext_resource type="Script" path="res://main.gd" id="1_m"]\n\n[node name="Main" type="Node"]\nscript = ExtResource("1_m")\n' > "$P/main.tscn"
cat > "$P/export_presets.cfg" <<'EOF'
[preset.0]

name="Pack"
platform="Linux"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/game.pck"

[preset.0.options]

binary_format/embed_pck=false
EOF
"$G" --headless --path "$P" --import > /dev/null 2>&1
"$G" --headless --path "$P" --export-pack "Pack" build/game.pck > "$RUN/export.log" 2>&1
[ -f "$P/build/game.pck" ] || { echo "FAIL export-pack produced no file"; tail -20 "$RUN/export.log"; exit 1; }
fail=0
editor_out="$(cd "$RUN" && timeout 60 "$G" --headless --path "$P" 2>&1 | grep naive_dir_access)"
pack_out="$(cd "$RUN" && timeout 60 "$G" --headless --main-pack "$P/build/game.pck" 2>&1 | grep naive_dir_access)"
echo "editor:   $editor_out"
echo "exported: $pack_out"
grep -q "naive_dir_access=2 registry_ok=true registry=3" <<<"$editor_out" && echo "PASS editor run" || { echo "FAIL editor run"; fail=1; }
grep -q "naive_dir_access=0 registry_ok=true registry=3" <<<"$pack_out" && echo "PASS exported pack: TrRegistry finds 3, DirAccess filter finds 0" || { echo "FAIL exported pack"; fail=1; }
exit $fail
