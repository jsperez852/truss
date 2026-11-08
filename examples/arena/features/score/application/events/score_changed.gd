class_name ScoreChanged
extends TrEvent

var points: int
var best: int


func _init(p_points: int, p_best: int) -> void:
	points = p_points
	best = p_best
