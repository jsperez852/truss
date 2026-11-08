#!/bin/bash
# Compiles the code blocks of a guide that start with "# file: res://...", in a throwaway project with
# addons/truss and the strict typing profile. Autoload blocks ("(autoload "Name")") are registered as autoloads.
# Usage: GODOT=/path/to/godot tools/check_doc_snippets.sh docs/guide/lite.md
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="${GODOT:-godot}"
AWK="$(command -v gawk || command -v awk)"  # needs GNU awk (match with a capture array)
DOC="$ROOT/${1:?usage: check_doc_snippets.sh <guide.md>}"
P="$(mktemp -d)"
trap 'rm -rf "$P"' EXIT
mkdir -p "$P/addons"
cp -r "$ROOT/addons/truss" "$P/addons/truss"
autoloads="$("$AWK" '
	/^```gdscript/ { inblock=1; first=1; next }
	/^```/ { inblock=0; next }
	inblock && first { first=0; if (match($0, /# file: (res:\/\/[^ ]+) \(autoload "([A-Za-z_]+)"\)/, m)) print m[2] "=\"*" m[1] "\"" }
' "$DOC")"
"$AWK" -v dir="$P" '
	/^```gdscript/ { inblock=1; first=1; out=""; next }
	/^```/ { if (out != "") close(out); inblock=0; out=""; next }
	inblock && first { first=0; if (match($0, /# file: res:\/\/([^ ]+)/, m)) { out=dir "/" m[1]; system("mkdir -p \"$(dirname \"" out "\")\"") } next }
	inblock && out != "" { print > out }
' "$DOC"
{
	printf 'config_version=5\n\n[application]\n\nconfig/name="snippets"\nconfig/features=PackedStringArray("4.5")\n\n[autoload]\n\n%s\n\n' "$autoloads"
	printf '[debug]\n\ngdscript/warnings/untyped_declaration=2\ngdscript/warnings/unsafe_property_access=2\ngdscript/warnings/unsafe_method_access=2\ngdscript/warnings/unsafe_call_argument=2\n'
} > "$P/project.godot"
cat > "$P/check.gd" <<'EOF'
extends SceneTree
func _initialize() -> void:
	var failures: int = 0
	var files: PackedStringArray = []
	for f: String in DirAccess.get_files_at("res://"):
		if f.get_extension() == "gd" and f != "check.gd":
			files.append("res://" + f)
	for path: String in files:
		var s: Script = load(path)
		if s == null or not (s.can_instantiate() or (s as GDScript).is_abstract()):
			printerr("FAILED ", path)
			failures += 1
	print("snippets: %d files, %d failures" % [files.size(), failures])
	quit(1 if failures > 0 else 0)
EOF
"$G" --headless --path "$P" --import > /dev/null 2>&1
out="$(timeout 60 "$G" --headless --path "$P" -s res://check.gd 2>&1)"; code=$?
grep -E "snippets:|FAILED|Parse Error" <<<"$out"
exit $code
