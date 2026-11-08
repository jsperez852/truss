class_name StartNextWaveHandler
extends TrRequestHandler

var _progress: WaveProgress
var _plan: WavePlan
var _bus: TrEventBus


func _init(progress: WaveProgress, plan: WavePlan, bus: TrEventBus) -> void:
	_progress = progress
	_plan = plan
	_bus = bus


func handles() -> Script:
	return StartNextWave


func handle(_request: TrRequest) -> TrResult:
	var result: TrResult = _progress.start_next(_plan)
	if result.is_ok():
		_bus.publish(WaveStarted.new(_progress.wave, _progress.remaining))
	return result
