class_name PlayerStats
extends TrStats
## The player's tunable stats. Cleared waves add modifiers (see CombatModule).


func _init() -> void:
	super({&"speed": 220.0, &"fire_interval": 0.15})
	declare(&"fire_interval", 0.15, 0.05, 1.0)
