class_name EnemyAlive
extends TrState
## Parent state: behavior shared by Wander and Chase (the hit flash).


func physics_update(delta: float) -> void:
	var enemy := owner as ArenaEnemy
	enemy.flash = maxf(enemy.flash - delta, 0.0)
