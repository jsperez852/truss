@abstract class_name ScoreStore
extends RefCounted
## Port: where the score is persisted.

@abstract func save_points(points: int) -> Error
