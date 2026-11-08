class_name MemoryScoreStore
extends ScoreStore
## Adapter: keeps the score in memory (a real game would write to user://).

var saved: int = 0


func save_points(points: int) -> Error:
	saved = points
	return OK
