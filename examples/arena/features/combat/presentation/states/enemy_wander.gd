class_name EnemyWander
extends TrState
## Drifts in a random direction until the player is close or the wander time runs out, then chases.

var _direction: Vector2
var _time_left: float = 0.0


func enter(_previous: TrState) -> void:
	var enemy := owner as ArenaEnemy
	var rng := RandomNumberGenerator.new()
	rng.seed = enemy.get_instance_id()
	_direction = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
	_time_left = enemy.config.max_wander_time


func physics_update(delta: float) -> void:
	var enemy := owner as ArenaEnemy
	enemy.velocity = _direction * enemy.config.enemy_speed * 0.5
	enemy.move_and_slide()
	_time_left -= delta
	var close: bool = enemy.target != null and enemy.global_position.distance_to(enemy.target.global_position) < enemy.config.chase_distance
	if close or _time_left <= 0.0:
		machine.transition_to(EnemyChase)
