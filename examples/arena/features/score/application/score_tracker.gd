class_name ScoreTracker
extends RefCounted
## Application service: turns kills into points.

var _board: ScoreBoard
var _bus: TrEventBus


func _init(board: ScoreBoard, bus: TrEventBus) -> void:
	_board = board
	_bus = bus
	_bus.subscribe(EnemyKilled, _on_enemy_killed)


func _on_enemy_killed(event: EnemyKilled) -> void:
	_board.add(event.points)
	_bus.publish(ScoreChanged.new(_board.points, _board.best))
