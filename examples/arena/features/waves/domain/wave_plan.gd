class_name WavePlan
extends RefCounted
## Domain: how many waves and how many enemies in each.

var total_waves: int = 3


func enemies_in(wave: int) -> int:
	return 2 + wave * 2


func is_last(wave: int) -> bool:
	return wave >= total_waves
