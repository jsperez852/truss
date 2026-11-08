class_name WaveCleared
extends TrEvent

var wave: int
var was_last: bool


func _init(p_wave: int, p_was_last: bool) -> void:
	wave = p_wave
	was_last = p_was_last
