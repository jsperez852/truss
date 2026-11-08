extends Node2D
## The arena scene: a match is playing -> saving (the high score, asynchronously) -> over.

var _mediator: TrMediator
var _bus: TrEventBus
var _options: GameOptions
var _phase := TrPhases.new(&"match")
var _waves_cleared: int = 0
var _last_score: int = 0


func _inject(c: TrServiceContainer) -> void:
	_mediator = c.get_service(TrMediator) as TrMediator
	_bus = c.get_service(TrEventBus) as TrEventBus
	_options = c.get_service(GameOptions) as GameOptions


func _ready() -> void:
	if _bus == null:
		return  # boot failed
	_phase.add(&"playing", {update = _check_autoplay_timeout, to = [&"saving"]})
	_phase.add(&"saving", {enter = _save_and_finish, to = [&"over"]})
	_phase.add(&"over")
	_phase.start(&"playing")
	_bus.subscribe(WaveCleared, _on_wave_cleared)
	_bus.subscribe(ScoreChanged, _on_score_changed)


func _process(delta: float) -> void:
	_phase.update(delta)


func _check_autoplay_timeout() -> void:
	if _options != null and _options.autoplay and _phase.elapsed() > _options.autoplay_timeout:
		printerr("TIMEOUT after %.0f s: waves cleared %d" % [_phase.elapsed(), _waves_cleared])
		get_tree().quit(1)


func _on_score_changed(event: ScoreChanged) -> void:
	_last_score = event.points


func _on_wave_cleared(event: WaveCleared) -> void:
	_waves_cleared = event.wave
	print("wave %d cleared" % event.wave)
	if event.was_last:
		# Deferred: the save is a request, sent after this event finishes dispatching.
		_phase.go.call_deferred(&"saving")


func _save_and_finish() -> void:
	var result: TrResult = await _mediator.send_async(SaveHighscore.new())
	var saved: bool = result.ok and result.value == true
	_phase.go(&"over")
	print("GAME OVER waves=%d score=%d record_saved=%s" % [_waves_cleared, _last_score, saved])
	if _options.autoplay:
		get_tree().quit(0 if result.ok else 1)
