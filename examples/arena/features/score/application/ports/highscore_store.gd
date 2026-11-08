@abstract class_name HighscoreStore
extends RefCounted
## Port: where the best score is kept. save_best may take time (await it).

@abstract func load_best() -> int
@abstract func save_best(points: int) -> Error
