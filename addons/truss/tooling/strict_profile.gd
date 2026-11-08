extends SceneTree
## Applies the Truss strict typing profile to the current project's project.godot.
##
## Usage:
##   godot --headless --path . -s res://addons/truss/tooling/strict_profile.gd              # dry run: lists changes
##   godot --headless --path . -s res://addons/truss/tooling/strict_profile.gd -- --apply   # writes project.godot
##   ... -- --apply --level=warn       # warnings instead of errors (for existing projects)
##   ... -- --apply --include-addons   # also check res://addons (Godot 4.7+ only; see below)
##
## Exit codes: 0 nothing to change or applied, 1 changes pending (dry run), 2 error.
##
## Which folders get warnings depends on the Godot version: 4.7 uses debug/gdscript/warnings/directory_rules
## (path -> 0 exclude / 1 include); 4.5 uses exclude_addons and ignores directory_rules.

const PREFIX: String = "debug/gdscript/warnings/"
## Warning -> level when --level=error (default). With --level=warn every 2 becomes 1.
const PROFILE: Dictionary[String, int] = {
	"untyped_declaration": 2,
	"unsafe_property_access": 2,
	"unsafe_method_access": 2,
	"unsafe_call_argument": 2,
	"unsafe_cast": 1,
	"return_value_discarded": 0,
	"inferred_declaration": 0,
}


func _initialize() -> void:
	var apply: bool = false
	var level: String = "error"
	var include_addons: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--apply":
			apply = true
		elif arg.begins_with("--level="):
			level = arg.trim_prefix("--level=")
		elif arg == "--include-addons":
			include_addons = true
	if level != "error" and level != "warn":
		printerr("strict_profile: --level must be error or warn, got %s" % level)
		quit(2)
		return
	var changes := PackedStringArray()
	for warning: String in PROFILE:
		var wanted: int = PROFILE[warning]
		if level == "warn" and wanted == 2:
			wanted = 1
		var key: String = PREFIX + warning
		var current: Variant = ProjectSettings.get_setting(key, null)
		if current == null or not (current is int) or (current as int) != wanted:
			changes.append("%s: %s -> %d" % [key, str(current), wanted])
			if apply:
				ProjectSettings.set_setting(key, wanted)
	if include_addons:
		var rules_key: String = PREFIX + "directory_rules"
		if ProjectSettings.has_setting(rules_key) and _supports_directory_rules():
			var rules: Dictionary = ProjectSettings.get_setting(rules_key, {})
			var addons_rule: int = rules.get("res://addons", 0)
			if addons_rule != 1:
				changes.append("%s: res://addons -> 1 (include)" % rules_key)
				if apply:
					rules["res://addons"] = 1
					ProjectSettings.set_setting(rules_key, rules)
		else:
			var exclude_key: String = PREFIX + "exclude_addons"
			var excluded: bool = ProjectSettings.get_setting(exclude_key, true)
			if excluded:
				changes.append("%s: true -> false" % exclude_key)
				if apply:
					ProjectSettings.set_setting(exclude_key, false)
	if changes.is_empty():
		print("strict_profile: project already uses the profile (level %s)" % level)
		quit(0)
		return
	for line: String in changes:
		print(("set   " if apply else "would set   ") + line)
	if not apply:
		print("strict_profile: dry run, %d change(s). Run again with -- --apply to write project.godot" % changes.size())
		quit(1)
		return
	var err: Error = ProjectSettings.save()
	if err != OK:
		printerr("strict_profile: could not save project.godot (%s)" % error_string(err))
		quit(2)
		return
	print("strict_profile: wrote %d change(s) to project.godot" % changes.size())
	quit(0)


func _supports_directory_rules() -> bool:
	var info: Dictionary = Engine.get_version_info()
	var major: int = info["major"]
	var minor: int = info["minor"]
	return major > 4 or (major == 4 and minor >= 7)
