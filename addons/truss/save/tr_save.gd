class_name TrSave
extends RefCounted
## A save file for one Dictionary of game data, with versions, migrations and a backup.
##
## Writes are atomic: the data goes to a temporary file, the previous save becomes [code]<path>.bak[/code], and
## only then the new file takes its place, so a crash while saving never leaves a half-written save. Reading a
## damaged file falls back to the backup. Values are stored with [method FileAccess.store_var] (Vector2, Color and
## other built-in types survive); objects are never stored or loaded.
## [codeblock]
## var save := TrSave.new("user://game.save", 2)
## save.add_migration(1, func(data: Dictionary) -> Dictionary:
##     data["coins"] = data.get("gold", 0)     # version 1 called it "gold"
##     data.erase("gold")
##     return data)
##
## var written: TrResult = save.write({"coins": wallet.balance(), "best": best_score})
## var data: Dictionary = save.read_or({"coins": 100.0, "best": 0})   # defaults fill missing keys
## [/codeblock]

const ERR_NOT_FOUND: StringName = &"not_found"
const ERR_WRITE: StringName = &"write_failed"
const ERR_CORRUPT: StringName = &"corrupt"
const ERR_NEWER_VERSION: StringName = &"newer_version"
const ERR_MIGRATION: StringName = &"migration_failed"

const _MARKER: String = "truss_save"

## Where the save lives (usually under [code]user://[/code]).
var path: String
## The version written by [method write]. Older files are migrated on [method read].
var version: int

var _password: String
var _migrations: Dictionary[int, Callable] = {}


## [param p_password]: when not empty, the file is encrypted with it ([method FileAccess.open_encrypted_with_pass]).
## Encryption keeps players from casually editing the file; it is not protection against a determined one.
func _init(p_path: String = "user://save.dat", p_version: int = 1, p_password: String = "") -> void:
	path = p_path
	version = maxi(p_version, 1)
	_password = p_password


## Registers how to turn data of [param from_version] into data of [code]from_version + 1[/code].
## [param migrate] takes the Dictionary and returns the migrated Dictionary. Returns this save, for chaining.
func add_migration(from_version: int, migrate: Callable) -> TrSave:
	_migrations[from_version] = migrate
	return self


func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(_backup_path())


## Saves [param data]. Success holds the path; failure is [constant ERR_WRITE] and leaves the previous save intact.
func write(data: Dictionary) -> TrResult:
	var tmp: String = path + ".tmp"
	var file: FileAccess = _open(tmp, FileAccess.WRITE)
	if file == null:
		return TrResult.failure(ERR_WRITE, "cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
	file.store_var({_MARKER: 1, "version": version, "data": data}, false)
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(tmp)
		return TrResult.failure(ERR_WRITE, "cannot write %s (%s)" % [tmp, error_string(write_error)])
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(_backup_path()):
			DirAccess.remove_absolute(_backup_path())
		var backup_error: Error = DirAccess.rename_absolute(path, _backup_path())
		if backup_error != OK:
			DirAccess.remove_absolute(tmp)
			return TrResult.failure(ERR_WRITE, "cannot keep a backup of %s (%s)" % [path, error_string(backup_error)])
	var move_error: Error = DirAccess.rename_absolute(tmp, path)
	if move_error != OK:
		return TrResult.failure(ERR_WRITE, "cannot replace %s (%s)" % [path, error_string(move_error)])
	return TrResult.success(path)


## Loads the data, migrated to [member version]. Falls back to the backup when the main file is missing or damaged.
## Failures: [constant ERR_NOT_FOUND] (never saved), [constant ERR_CORRUPT], [constant ERR_NEWER_VERSION] (saved by a
## newer build of the game), [constant ERR_MIGRATION].
func read() -> TrResult:
	if not exists():
		return TrResult.failure(ERR_NOT_FOUND, "%s does not exist" % path)
	var main: TrResult = _read_file(path)
	if main.is_ok() or main.error == ERR_NEWER_VERSION or main.error == ERR_MIGRATION:
		return main
	var backup: TrResult = _read_file(_backup_path())
	if backup.is_ok():
		push_warning("TrSave: %s (%s); loaded the backup" % [main.message, path])
		return backup
	return main


## The saved data, with [param defaults] filling the keys it doesn't have; [param defaults] alone when there is no
## usable save (reported with [code]push_warning[/code] unless the save simply doesn't exist yet).
func read_or(defaults: Dictionary) -> Dictionary:
	var loaded: TrResult = read()
	if loaded.is_err():
		if loaded.error != ERR_NOT_FOUND:
			push_warning("TrSave: %s" % loaded.message)
		return defaults.duplicate(true)
	var data: Dictionary = loaded.value
	data.merge(defaults.duplicate(true))
	return data


## Deletes the save and its backup.
func erase() -> void:
	for file_path: String in [path, _backup_path(), path + ".tmp"]:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)


func _read_file(file_path: String) -> TrResult:
	if not FileAccess.file_exists(file_path):
		return TrResult.failure(ERR_NOT_FOUND, "%s does not exist" % file_path)
	var file: FileAccess = _open(file_path, FileAccess.READ)
	if file == null:
		return TrResult.failure(ERR_CORRUPT, "cannot open %s (%s)" % [file_path, error_string(FileAccess.get_open_error())])
	var raw: Variant = file.get_var(false) if file.get_length() > 0 else null
	file.close()
	if typeof(raw) != TYPE_DICTIONARY:
		return TrResult.failure(ERR_CORRUPT, "%s is not a Truss save" % file_path)
	var envelope: Dictionary = raw
	if not envelope.has(_MARKER) or typeof(envelope.get("data")) != TYPE_DICTIONARY or typeof(envelope.get("version")) != TYPE_INT:
		return TrResult.failure(ERR_CORRUPT, "%s is not a Truss save" % file_path)
	var saved_version: int = envelope["version"]
	var data: Dictionary = envelope["data"]
	if saved_version > version:
		return TrResult.failure(ERR_NEWER_VERSION, "%s has version %d; this build reads up to %d" % [file_path, saved_version, version])
	while saved_version < version:
		if not _migrations.has(saved_version):
			return TrResult.failure(ERR_MIGRATION, "no migration from version %d (add_migration(%d, ...))" % [saved_version, saved_version])
		var migrated: Variant = _migrations[saved_version].call(data)
		if typeof(migrated) != TYPE_DICTIONARY:
			return TrResult.failure(ERR_MIGRATION, "the migration from version %d did not return a Dictionary" % saved_version)
		data = migrated
		saved_version += 1
	return TrResult.success(data)


func _open(file_path: String, mode: FileAccess.ModeFlags) -> FileAccess:
	if _password.is_empty():
		return FileAccess.open(file_path, mode)
	return FileAccess.open_encrypted_with_pass(file_path, mode, _password)


func _backup_path() -> String:
	return path + ".bak"
