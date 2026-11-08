class_name EnemyWander
extends TrState

var _direction: Vector2


func enter(_previous: TrState) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = owner.get_instance_id()
	_direction = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))


func physics_update(_delta: float) -> void:
	var enemy := owner as ArenaEnemy
	enemy.velocity = _direction * enemy.config.enemy_speed * 0.5
	enemy.move_and_slide()
	if enemy.target != null and enemy.global_position.distance_to(enemy.target.global_position) < enemy.config.chase_distance:
		machine.transition_to(EnemyChase)
