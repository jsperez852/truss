extends Node2D
## The arena scene: ends the game after the last wave and saves the high score (asynchronously).

var _mediator: TrMediator
var _bus: TrEventBus
var _options: GameOptions
var _elapsed: float = 0.0
var _finished: bool = false
var _waves_cleared: int = 0
var _last_score: int = 0


func _inject(c: TrServiceContainer) -> void:
	_mediator = c.get_service(TrMediator) as TrMediator
	_bus = c.get_service(TrEventBus) as TrEventBus
	_options = c.get_service(GameOptions) as GameOptions


func _ready() -> void:
	if _bus == null:
		return  # boot failed
	_bus.subscribe(WaveCleared, _on_wave_cleared)
	_bus.subscribe(ScoreChanged, _on_score_changed)


func _exit_tree() -> void:
	if _bus != null:
		_bus.unsubscribe_all(self)


func _process(delta: float) -> void:
	_elapsed += delta
	if _options != null and _options.autoplay and not _finished and _elapsed > _options.autoplay_timeout:
		printerr("TIMEOUT after %.0f s: waves cleared %d" % [_elapsed, _waves_cleared])
		get_tree().quit(1)


func _on_score_changed(event: ScoreChanged) -> void:
	_last_score = event.points


func _on_wave_cleared(event: WaveCleared) -> void:
	_waves_cleared = event.wave
	print("wave %d cleared" % event.wave)
	if event.was_last and not _finished:
		_finished = true
		_finish.call_deferred()


func _finish() -> void:
	var result: TrResult = await _mediator.send_async(SaveHighscore.new())
	var saved: bool = result.ok and result.value == true
	print("GAME OVER waves=%d score=%d record_saved=%s" % [_waves_cleared, _last_score, saved])
	if _options.autoplay:
		get_tree().quit(0 if result.ok else 1)
