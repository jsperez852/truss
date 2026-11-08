class_name EnemyKilled
extends TrEvent

var points: int
var at: Vector2


func _init(p_points: int, p_at: Vector2) -> void:
	points = p_points
	at = p_at
