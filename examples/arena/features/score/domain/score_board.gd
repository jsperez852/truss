class_name ScoreBoard
extends RefCounted
## Domain: points of this run and the best score so far.

var points: int = 0
var best: int = 0
var _best_at_start: int = 0


func _init(previous_best: int = 0) -> void:
	best = previous_best
	_best_at_start = previous_best


func add(amount: int) -> void:
	points += amount
	best = maxi(best, points)


func is_record() -> bool:
	return points > _best_at_start
