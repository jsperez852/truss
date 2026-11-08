extends SceneTree
## Truss code generators. Writes typed, strict-clean stubs into res://features/<feature>/. Never overwrites files.
##
## Usage: godot --headless --path . -s res://addons/truss/tooling/generate.gd -- <command> <feature> [Name]
##   module  <feature>          features/<feature>/<feature>_module.gd and the layer folders
##   usecase <feature> <Name>   application/<name>_request.gd and <name>_handler.gd (TrRequest + TrRequestHandler)
##   port    <feature> <Name>   application/ports/<name>.gd (@abstract) and infrastructure/memory_<name>.gd
##   event   <feature> <Name>   application/events/<name>.gd (TrEvent)
## Options: --root=res://features (base folder), --dry-run (print paths only).
## Exit codes: 0 written, 1 a file already exists (nothing written), 2 usage error.

const USAGE: String = "usage: generate.gd -- <module|usecase|port|event> <feature> [Name] [--root=res://features] [--dry-run]"

var _root: String = "res://features"
var _dry_run: bool = false


func _initialize() -> void:
	var positional := PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--root="):
			_root = arg.trim_prefix("--root=").trim_suffix("/")
		elif arg == "--dry-run":
			_dry_run = true
		else:
			positional.append(arg)
	if positional.size() < 2:
		printerr(USAGE)
		quit(2)
		return
	var command: String = positional[0]
	var feature: String = positional[1].to_snake_case()
	var type_name: String = positional[2].to_pascal_case() if positional.size() > 2 else ""
	if not _valid_identifier(feature) or (not type_name.is_empty() and not _valid_identifier(type_name)):
		printerr("generate: names must be identifiers (letters, digits, _), got %s %s" % [positional[1], type_name])
		quit(2)
		return
	var files: Dictionary[String, String] = {}
	var hint: String = ""
	match command:
		"module":
			files = _module(feature)
		"usecase", "port", "event":
			if type_name.is_empty():
				printerr("generate: %s needs a Name\n%s" % [command, USAGE])
				quit(2)
				return
			if command == "usecase":
				files = _usecase(feature, type_name)
				hint = "Register it in %sModule.start():\n\tmediator.register(%sHandler.new())" % [feature.to_pascal_case(), type_name]
			elif command == "port":
				files = _port(feature, type_name)
				hint = "Register an adapter in %sModule.register():\n\tc.singleton(%s, func() -> %s: return Memory%s.new())" % [feature.to_pascal_case(), type_name, type_name, type_name]
			else:
				files = _event(feature, type_name)
				hint = "Publish it with bus.publish(%s.new()) and subscribe with bus.subscribe(%s, handler)" % [type_name, type_name]
		_:
			printerr("generate: unknown command %s\n%s" % [command, USAGE])
			quit(2)
			return
	quit(_write(files, hint))


func _write(files: Dictionary[String, String], hint: String) -> int:
	for path: String in files:
		if FileAccess.file_exists(path):
			printerr("generate: %s already exists; nothing was written" % path)
			return 1
	for path: String in files:
		if _dry_run:
			print("would create ", path)
			continue
		var dir: String = path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			printerr("generate: cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
			return 2
		file.store_string(files[path])
		print("created ", path)
	if not hint.is_empty():
		print(hint)
	return 0


func _valid_identifier(text: String) -> bool:
	return RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*$").search(text) != null


func _module(feature: String) -> Dictionary[String, String]:
	var base: String = _root.path_join(feature)
	var cls: String = feature.to_pascal_case() + "Module"
	var files: Dictionary[String, String] = {}
	files[base.path_join(feature + "_module.gd")] = """class_name %s
extends TrModule
## Entry point of the %s feature: registers its services.


func dependencies() -> Array[Script]:
	return []


func register(_c: TrServiceContainer) -> void:
	pass


func start(_c: TrServiceContainer) -> void:
	pass
""" % [cls, feature]
	for layer: String in ["domain", "application", "infrastructure", "presentation"]:
		files[base.path_join(layer).path_join(".gitkeep")] = ""
	return files


func _usecase(feature: String, type_name: String) -> Dictionary[String, String]:
	var dir: String = _root.path_join(feature).path_join("application")
	var snake: String = type_name.to_snake_case()
	var request: String = type_name + "Request"
	var handler: String = type_name + "Handler"
	var files: Dictionary[String, String] = {}
	files[dir.path_join(snake + "_request.gd")] = """class_name %s
extends TrRequest
## Input of the %s use case. Add typed fields and set them in _init().


func _init() -> void:
	pass
""" % [request, type_name]
	files[dir.path_join(snake + "_handler.gd")] = """class_name %s
extends TrRequestHandler
## Handles %s. Receive ports and domain objects in _init().


func _init() -> void:
	pass


func handles() -> Script:
	return %s


func handle(request: TrRequest) -> TrResult:
	return TrResult.failure(&"not_implemented", "%%s is not implemented yet" %% TrContracts.describe_value(request))
""" % [handler, request, request]
	return files


func _port(feature: String, type_name: String) -> Dictionary[String, String]:
	var base: String = _root.path_join(feature)
	var snake: String = type_name.to_snake_case()
	var files: Dictionary[String, String] = {}
	files[base.path_join("application/ports").path_join(snake + ".gd")] = """@abstract class_name %s
extends RefCounted
## Port: what the %s feature needs from the outside world. Declare @abstract methods, for example:
## @abstract func save(data: Dictionary) -> Error
""" % [type_name, feature]
	files[base.path_join("infrastructure").path_join("memory_" + snake + ".gd")] = """class_name Memory%s
extends %s
## In-memory adapter for %s, for tests and prototypes. Implement every abstract method of the port.
""" % [type_name, type_name, type_name]
	return files


func _event(feature: String, type_name: String) -> Dictionary[String, String]:
	var path: String = _root.path_join(feature).path_join("application/events").path_join(type_name.to_snake_case() + ".gd")
	var files: Dictionary[String, String] = {}
	files[path] = """class_name %s
extends TrEvent
## A fact the %s feature announces (past tense). Add typed fields and set them in _init().


func _init() -> void:
	pass
""" % [type_name, feature]
	return files
