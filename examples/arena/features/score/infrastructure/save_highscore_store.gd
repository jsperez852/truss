class_name SaveHighscoreStore
extends HighscoreStore
## Adapter: keeps the best score in a TrSave file. Imports the ConfigFile that earlier versions wrote, once.
## Waits a frame before writing, like slow storage would.

const LEGACY_PATH: String = "user://arena_highscore.cfg"

var _save: TrSave


func _init(path: String) -> void:
	_save = TrSave.new(path)


func load_best() -> int:
	if not _save.exists():
		_import_legacy()
	var data: Dictionary = _save.read_or({"best": 0})
	var best: int = data["best"]
	return best


func save_best(points: int) -> Error:
	await (Engine.get_main_loop() as SceneTree).process_frame
	var written: TrResult = _save.write({"best": points})
	if written.is_err():
		push_warning(written.message)
		return ERR_CANT_CREATE
	return OK


func _import_legacy() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LEGACY_PATH) != OK:
		return
	var best: int = cfg.get_value("score", "best", 0)
	_save.write({"best": best})
