extends Node
## Composition root (autoload "App", listed after "Truss"). Boots the modules before the main scene loads.
## Run with -- --break=cycle, --break=missing-module or --break=missing-registration to see the failures.


func _ready() -> void:
	var modules: Array = [CoreModule.new(), StorageModule.new(), ScoreModule.new()]
	match _break_mode():
		"cycle":
			modules.append(BrokenModules.CycleA.new())
			modules.append(BrokenModules.CycleB.new())
		"missing-module":
			modules = [CoreModule.new(), ScoreModule.new()]
		"missing-registration":
			modules = [BrokenModules.NeedsUnregisteredService.new()]
	var result: TrResult = Truss.boot(modules)
	if result.is_err():
		printerr("BOOT FAILED [%s]\n%s" % [result.error, result.message])
		get_tree().quit(1)
		return
	print("booted: ", ", ".join(_names(modules)))


func _break_mode() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--break="):
			return arg.trim_prefix("--break=")
	return ""


func _names(modules: Array) -> PackedStringArray:
	var names := PackedStringArray()
	for module: Variant in modules:
		names.append((module as TrModule).module_name())
	return names
