extends Label
## Shows the wave and the score, updated through events.

var _bus: TrEventBus
var _wave: int = 0
var _points: int = 0
var _best: int = 0


func _inject(c: TrServiceContainer) -> void:
	_bus = c.get_service(TrEventBus) as TrEventBus
	_best = (c.get_service(ScoreBoard) as ScoreBoard).best


func _ready() -> void:
	if _bus == null:
		return
	_bus.subscribe(WaveStarted, _on_wave_started)
	_bus.subscribe(ScoreChanged, _on_score_changed)
	_refresh()


func _exit_tree() -> void:
	if _bus != null:
		_bus.unsubscribe_all(self)


func _on_wave_started(event: WaveStarted) -> void:
	_wave = event.wave
	_refresh()


func _on_score_changed(event: ScoreChanged) -> void:
	_points = event.points
	_best = event.best
	_refresh()


func _refresh() -> void:
	text = "Wave %d | Score %d | Best %d" % [_wave, _points, _best]
