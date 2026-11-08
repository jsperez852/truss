class_name EnemyChase
extends TrState


func physics_update(_delta: float) -> void:
	var enemy := owner as ArenaEnemy
	if enemy.target == null:
		return
	enemy.velocity = enemy.global_position.direction_to(enemy.target.global_position) * enemy.config.enemy_speed
	enemy.move_and_slide()
