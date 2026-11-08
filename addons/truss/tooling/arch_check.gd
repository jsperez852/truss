extends SceneTree
## Truss architecture checker: layer boundaries, feature boundaries and forbidden classes, driven by a config file.
##
## Usage:
##   godot --headless --path . -s res://addons/truss/tooling/arch_check.gd
##   godot --headless --path . -s res://addons/truss/tooling/arch_check.gd -- --config=res://architecture.cfg --junit=res://reports/arch.xml
##   godot --headless --path . -s res://addons/truss/tooling/arch_check.gd -- --write-default-config
## Exit codes: 0 no violations, 1 violations, 2 configuration error.
## Run "godot --headless --path . --import" first on a fresh checkout so class_name scripts are registered.

const DEFAULT_CONFIG: String = "res://architecture.cfg"
const DEFAULT_CONFIG_TEXT: String = """; Truss architecture rules (addons/truss/tooling/arch_check.gd)
[settings]
ignore=["res://addons/*", "res://test/*", "res://tests/*", "res://tools/*"]

[layers]
; layer = glob patterns (String.match: * matches any characters, including /)
domain=["res://shared/domain/*", "res://features/*/domain/*"]
application=["res://features/*/application/*"]
infrastructure=["res://features/*/infrastructure/*"]
presentation=["res://features/*/presentation/*", "res://common/*"]
composition=["res://app/*", "res://features/*_module.gd"]

[allow]
; layer = layers it may depend on (its own layer is always allowed; "*" = any)
domain=[]
application=["domain"]
infrastructure=["application", "domain"]
presentation=["application", "domain"]
composition=["*"]

[rules]
no_nodes=["domain", "application"]
no_scene_access=["domain", "application"]

[features]
; files under root/<feature>/ belong to that feature. Other features may only use these layers of it.
root="res://features/"
public_layers=["domain", "application"]

[forbid]
; layer = class names it may not reference
domain=["TrServiceContainer", "TrInjector", "TrBootstrap", "TrMediator"]
application=["TrInjector", "TrBootstrap"]
"""

var _layers: Array[Dictionary] = []
var _ignore: PackedStringArray = []
var _feature_root: String = ""
var _public_layers: PackedStringArray = []
var _forbid: Dictionary[String, PackedStringArray] = {}
var _class_paths: Dictionary[String, String] = {}
var _autoloads: PackedStringArray = []
var _violations: Array[Dictionary] = []  # {path, message}
var _checked: PackedStringArray = []


func _initialize() -> void:
	var config_path: String = DEFAULT_CONFIG
	var junit_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--config="):
			config_path = arg.trim_prefix("--config=")
		elif arg.begins_with("--junit="):
			junit_path = arg.trim_prefix("--junit=")
		elif arg == "--write-default-config":
			quit(_write_default_config(config_path))
			return
	if not _load_config(config_path):
		quit(2)
		return
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		var class_key: String = entry["class"]
		var class_path: String = entry["path"]
		_class_paths[class_key] = class_path
	for prop: Dictionary in ProjectSettings.get_property_list():
		var key: String = prop["name"]
		if key.begins_with("autoload/"):
			_autoloads.append(key.trim_prefix("autoload/"))
	var files: PackedStringArray = []
	_collect("res://", files)
	for path: String in files:
		_check_file(path)
	for v: Dictionary in _violations:
		printerr("VIOLATION %s %s" % [v["path"], v["message"]])
	print("arch_check: %d files, %d violations" % [_checked.size(), _violations.size()])
	if not junit_path.is_empty():
		_write_junit(junit_path)
	quit(1 if _violations.size() > 0 else 0)


func _write_default_config(path: String) -> int:
	if FileAccess.file_exists(path):
		printerr("arch_check: %s already exists; not overwriting it" % path)
		return 2
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("arch_check: cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return 2
	file.store_string(DEFAULT_CONFIG_TEXT)
	print("arch_check: wrote %s" % path)
	return 0


func _load_config(path: String) -> bool:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(path)
	if err != OK:
		printerr("arch_check: cannot read %s (%s). Create one with --write-default-config" % [path, error_string(err)])
		return false
	if not cfg.has_section("layers"):
		printerr("arch_check: %s has no [layers] section" % path)
		return false
	_ignore = _strings(cfg.get_value("settings", "ignore", ["res://addons/*", "res://test/*", "res://tests/*"]))
	var no_nodes: PackedStringArray = _strings(cfg.get_value("rules", "no_nodes", []))
	var no_scene: PackedStringArray = _strings(cfg.get_value("rules", "no_scene_access", []))
	for layer_name: String in cfg.get_section_keys("layers"):
		_layers.append({
			"name": layer_name,
			"patterns": _strings(cfg.get_value("layers", layer_name, [])),
			"allow": _strings(cfg.get_value("allow", layer_name, [])),
			"no_nodes": no_nodes.has(layer_name),
			"no_scene_access": no_scene.has(layer_name),
		})
	var root: String = str(cfg.get_value("features", "root", ""))
	_feature_root = root if root.is_empty() or root.ends_with("/") else root + "/"
	_public_layers = _strings(cfg.get_value("features", "public_layers", ["domain", "application"]))
	if cfg.has_section("forbid"):
		for layer_name: String in cfg.get_section_keys("forbid"):
			_forbid[layer_name] = _strings(cfg.get_value("forbid", layer_name, []))
	return true


func _strings(value: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if value is Array or value is PackedStringArray:
		for item: Variant in value:
			out.append(str(item))
	return out


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		if sub.begins_with("."):
			continue
		_collect(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		var full: String = dir_path.path_join(file)
		if file.get_extension() == "gd" and not _ignored(full):
			out.append(full)


func _ignored(path: String) -> bool:
	for pattern: String in _ignore:
		if path.match(pattern):
			return true
	return false


func _layer_of(path: String) -> Dictionary:
	for layer: Dictionary in _layers:
		var patterns: PackedStringArray = layer["patterns"]
		for pattern: String in patterns:
			if path.match(pattern):
				return layer
	return {}


func _feature_of(path: String) -> String:
	if _feature_root.is_empty() or not path.begins_with(_feature_root):
		return ""
	var rest: String = path.trim_prefix(_feature_root)
	return rest.get_slice("/", 0) if rest.contains("/") else ""


func _check_file(path: String) -> void:
	var layer: Dictionary = _layer_of(path)
	if layer.is_empty():
		return
	_checked.append(path)
	var layer_name: String = layer["name"]
	var no_scene_access: bool = layer["no_scene_access"]
	var no_nodes: bool = layer["no_nodes"]
	var source: String = FileAccess.get_file_as_string(path)
	var code: String = _strip(source, false)
	var bare: String = _strip(source, true)
	var forbidden: PackedStringArray = _forbid.get(layer_name, PackedStringArray())
	# 1. references to other scripts by class_name, and forbidden classes
	var ident := RegEx.create_from_string("\\b[A-Z][A-Za-z0-9_]*\\b")
	var seen: Dictionary[String, bool] = {}
	for m: RegExMatch in ident.search_all(bare):
		var name: String = m.get_string()
		if seen.has(name):
			continue
		seen[name] = true
		if forbidden.has(name):
			_report(path, layer_name, "uses %s, which is forbidden in this layer" % name)
		if _class_paths.has(name) and _class_paths[name] != path:
			_check_dependency(path, layer, _class_paths[name], name)
	# 2. res:// paths in strings
	var res_path := RegEx.create_from_string("\"(res://[^\"]+\\.(?:gd|tscn|scn|tres|res))\"")
	for m: RegExMatch in res_path.search_all(code):
		var target: String = m.get_string(1)
		if target.get_extension() == "gd":
			_check_dependency(path, layer, target, target)
		elif no_scene_access and target.get_extension() in ["tscn", "scn"]:
			_report(path, layer_name, "loads a scene (%s)" % target)
	# 3. scene tree and autoload access
	if no_scene_access:
		for autoload: String in _autoloads:
			if RegEx.create_from_string("\\b%s\\b" % autoload).search(bare) != null:
				_report(path, layer_name, "uses autoload %s" % autoload)
		var scene_access := RegEx.create_from_string("\\bget_tree\\s*\\(|\\bget_node(?:_or_null)?\\s*\\(|\\$[A-Za-z%\"]|\"/root/")
		var hit: RegExMatch = scene_access.search(code)
		if hit != null:
			_report(path, layer_name, "accesses the scene tree (%s)" % hit.get_string().strip_edges())
	# 4. Node base class
	if no_nodes:
		var script: Script = load(path)
		if script != null:
			var base: StringName = script.get_instance_base_type()
			if ClassDB.is_parent_class(base, &"Node"):
				_report(path, layer_name, "extends a Node type (%s)" % base)


func _check_dependency(path: String, layer: Dictionary, target: String, label: String) -> void:
	var target_layer: Dictionary = _layer_of(target)
	var where: String = target if label == target else "%s, %s" % [label, target]
	var layer_name: String = layer["name"]
	var target_layer_name: String = target_layer.get("name", "")
	if not target_layer.is_empty():
		var allow: PackedStringArray = layer["allow"]
		var same: bool = layer["name"] == target_layer["name"]
		if not same and not allow.has("*") and not allow.has(target_layer_name):
			_report(path, layer_name, "depends on %s (layer %s)" % [where, target_layer_name])
			return
	var from_feature: String = _feature_of(path)
	var to_feature: String = _feature_of(target)
	if from_feature.is_empty() or to_feature.is_empty() or from_feature == to_feature:
		return
	if not _public_layers.has(target_layer_name) and not (layer["allow"] as PackedStringArray).has("*"):
		_report(path, layer_name, "reaches into feature %s's %s (%s); only %s are public to other features" % [
			to_feature, target_layer_name if not target_layer_name.is_empty() else "unlayered code", where, ", ".join(_public_layers)])


func _report(path: String, layer_name: String, what: String) -> void:
	_violations.append({"path": path, "message": "[%s] %s" % [layer_name, what]})


func _write_junit(path: String) -> void:
	var by_file: Dictionary[String, PackedStringArray] = {}
	for v: Dictionary in _violations:
		var file_path: String = v["path"]
		if not by_file.has(file_path):
			by_file[file_path] = PackedStringArray()
		var message: String = v["message"]
		by_file[file_path].append(message)
	var lines := PackedStringArray()
	lines.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
	lines.append("<testsuites name=\"arch_check\" tests=\"%d\" failures=\"%d\">" % [_checked.size(), by_file.size()])
	lines.append("  <testsuite name=\"architecture\" tests=\"%d\" failures=\"%d\">" % [_checked.size(), by_file.size()])
	for file_path: String in _checked:
		lines.append("    <testcase classname=\"architecture\" name=\"%s\">" % file_path.xml_escape(true))
		if by_file.has(file_path):
			var messages: PackedStringArray = by_file[file_path]
			lines.append("      <failure message=\"%d violation(s)\">%s</failure>" % [messages.size(), "\n".join(messages).xml_escape()])
		lines.append("    </testcase>")
	lines.append("  </testsuite>")
	lines.append("</testsuites>")
	var dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("arch_check: cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string("\n".join(lines) + "\n")
	print("arch_check: JUnit report written to %s" % path)


## Removes comments. With blank_strings, string contents are replaced by spaces so words in messages
## are not taken for class names.
func _strip(source: String, blank_strings: bool) -> String:
	var out := PackedStringArray()
	for line: String in source.split("\n"):
		var chars := PackedStringArray()
		var in_string: bool = false
		var escaped: bool = false
		var quote: String = ""
		for i: int in line.length():
			var c: String = line[i]
			if in_string:
				if escaped:
					escaped = false
				elif c == "\\":
					escaped = true
				elif c == quote:
					in_string = false
					chars.append(c)
					continue
				chars.append(" " if blank_strings else c)
				continue
			if c == "\"" or c == "'":
				in_string = true
				quote = c
			elif c == "#":
				break
			chars.append(c)
		out.append("".join(chars))
	return "\n".join(out)
