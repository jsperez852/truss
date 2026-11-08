class_name WaveTracker
extends RefCounted
## Application service: counts kills and announces cleared waves.

var _progress: WaveProgress
var _plan: WavePlan
var _bus: TrEventBus


func _init(progress: WaveProgress, plan: WavePlan, bus: TrEventBus) -> void:
	_progress = progress
	_plan = plan
	_bus = bus
	_bus.subscribe(EnemyKilled, _on_enemy_killed)


func _on_enemy_killed(_event: EnemyKilled) -> void:
	if _progress.enemy_down():
		_bus.publish(WaveCleared.new(_progress.wave, _plan.is_last(_progress.wave)))
