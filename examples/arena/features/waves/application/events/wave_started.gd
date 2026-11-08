class_name WaveStarted
extends TrEvent

var wave: int
var enemies: int


func _init(p_wave: int, p_enemies: int) -> void:
	wave = p_wave
	enemies = p_enemies
