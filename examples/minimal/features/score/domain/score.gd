class_name Score
extends RefCounted
## Domain: the score and its rules. No nodes, no engine services.

const ERR_INVALID_POINTS: StringName = &"invalid_points"

var points: int = 0


func add(amount: int) -> TrResult:
	if amount <= 0:
		return TrResult.failure(ERR_INVALID_POINTS, "points must be positive, got %d" % amount)
	points += amount
	return TrResult.success(points)
