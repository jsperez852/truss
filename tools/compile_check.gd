extends SceneTree
## Loads every script under res://addons/truss and fails if any doesn't compile.
## Usage: godot --headless --path . -s res://tools/compile_check.gd

func _initialize() -> void:
	var failures: int = 0
	var files: PackedStringArray = []
	_collect("res://addons/truss", files)
	for path: String in files:
		var script: Script = load(path)
		var ok: bool = script != null and (script.can_instantiate() or (script as GDScript).is_abstract())
		if not ok:
			printerr("FAILED: ", path)
			failures += 1
	print("compile_check: %d scripts, %d failures" % [files.size(), failures])
	quit(1 if failures > 0 else 0)

func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if file.get_extension() == "gd":
			out.append(dir_path.path_join(file))
