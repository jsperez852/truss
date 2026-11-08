class_name Health
extends RefCounted
## Domain: hit points and their rules.

const ERR_DEAD: StringName = &"already_dead"
const ERR_INVALID: StringName = &"invalid_damage"

var maximum: int
var current: int


func _init(max_health: int) -> void:
	maximum = max_health
	current = max_health


func damage(amount: int) -> TrResult:
	if current <= 0:
		return TrResult.failure(ERR_DEAD, "already dead")
	if amount <= 0:
		return TrResult.failure(ERR_INVALID, "damage must be positive, got %d" % amount)
	current = maxi(current - amount, 0)
	return TrResult.success(current)


func is_dead() -> bool:
	return current <= 0
