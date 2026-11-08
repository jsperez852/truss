extends Node2D
## Asks the waves feature for the next wave and spawns its enemies around the arena.

const ENEMY_SCENE: PackedScene = preload("res://features/combat/presentation/enemy.tscn")
const CENTER: Vector2 = Vector2(480, 270)

@export var player: Node2D

var _mediator: TrMediator
var _bus: TrEventBus


func _inject(c: TrServiceContainer) -> void:
	_mediator = c.get_service(TrMediator) as TrMediator
	_bus = c.get_service(TrEventBus) as TrEventBus


func _ready() -> void:
	if _bus == null:
		return
	_bus.subscribe(WaveCleared, _on_wave_cleared)
	_start_next_wave.call_deferred()


func _exit_tree() -> void:
	if _bus != null:
		_bus.unsubscribe_all(self)


func _on_wave_cleared(event: WaveCleared) -> void:
	if not event.was_last:
		# Deferred: the kill that cleared the wave happens inside a physics callback, where adding bodies isn't allowed.
		_start_next_wave.call_deferred()


func _start_next_wave() -> void:
	var result: TrResult = _mediator.send(StartNextWave.new())
	if result.is_err():
		print("no wave started: ", result.message)
		return
	var count: int = result.value
	for i: int in count:
		var enemy := ENEMY_SCENE.instantiate() as ArenaEnemy
		enemy.target = player
		enemy.position = CENTER + Vector2.RIGHT.rotated(TAU * float(i) / float(count)) * 380.0
		get_parent().add_child(enemy)
