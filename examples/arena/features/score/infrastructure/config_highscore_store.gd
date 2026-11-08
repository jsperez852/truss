class_name ConfigHighscoreStore
extends HighscoreStore
## Adapter: keeps the best score in a ConfigFile in user://. Waits a frame before writing, like slow storage would.

var _path: String


func _init(path: String) -> void:
	_path = path


func load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return 0
	var best: int = cfg.get_value("score", "best", 0)
	return best


func save_best(points: int) -> Error:
	await (Engine.get_main_loop() as SceneTree).process_frame
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", points)
	return cfg.save(_path)
