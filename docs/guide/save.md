# save: TrSave

One save file holding one Dictionary, written so that a crash or a power cut never leaves a broken save.

```gdscript
var save := TrSave.new("user://game.save", 2)
save.add_migration(1, func(data: Dictionary) -> Dictionary:
	data["coins"] = data.get("gold", 0)       # version 1 called it "gold"
	data.erase("gold")
	return data)

var written: TrResult = save.write({"coins": wallet.snapshot(), "best": best_score, "spawn": Vector2(40, 12)})
if written.is_err():
	push_warning(written.message)

var data: Dictionary = save.read_or({"coins": {"coins": 100.0}, "best": 0})   # defaults fill missing keys
```

## How it writes

1. The data goes to `<path>.tmp`.
2. The previous save becomes `<path>.bak`.
3. The temporary file is renamed to `<path>`.

If the game dies at any step, the next `read()` finds either the new save or the backup. A damaged main file
falls back to the backup with a warning.

Values are stored with `FileAccess.store_var`, so `Vector2`, `Color`, arrays and nested dictionaries round-trip.
Objects are never stored or loaded (no code can come in through a save file). Pass a password to encrypt:
`TrSave.new(path, 1, "key")`. That stops casual editing, not a determined player.

## Reference

| Member | Notes |
|---|---|
| `TrSave.new(path = "user://save.dat", version = 1, password = "")` | |
| `write(data) -> TrResult` | Success holds the path. Error: `write_failed` (the previous save stays) |
| `read() -> TrResult` | Success holds the data, migrated. Errors: `not_found`, `corrupt`, `newer_version`, `migration_failed` |
| `read_or(defaults) -> Dictionary` | Saved data merged over `defaults`; `defaults` alone when there's no usable save (warns unless the file doesn't exist yet) |
| `add_migration(from_version, func(data) -> Dictionary) -> TrSave` | Runs for files older than `version`, one version at a time |
| `exists()`, `erase()` | `erase` also removes the backup |

## Versions

Bump `version` when the shape of the data changes and add a migration from the previous version. A file written
by a newer build (`newer_version`) is not touched, so a player who goes back to an old build doesn't lose it.

## Moving an existing save to TrSave

`TrSave` doesn't read files it didn't write. Read the old file once and write it with `TrSave`:

```gdscript
func _load_best() -> int:
	if not save.exists() and FileAccess.file_exists("user://score.dat"):
		var old := FileAccess.open("user://score.dat", FileAccess.READ)
		save.write({"best": old.get_32()})
	return save.read_or({"best": 0})["best"]
```
