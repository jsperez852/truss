class_name EnemyDead
extends TrState
## Announces the kill, stops colliding and removes the enemy shortly after.

var _remaining: float = 0.2


func enter(_previous: TrState) -> void:
	var enemy := owner as ArenaEnemy
	enemy.remove_from_group(&"enemies")
	enemy.velocity = Vector2.ZERO
	($"../../Shape" as CollisionShape2D).set_deferred(&"disabled", true)
	enemy.bus.publish(EnemyKilled.new(enemy.config.points_per_enemy, enemy.global_position))


func update(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		owner.queue_free()
