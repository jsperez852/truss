class_name AddPointsHandler
extends TrRequestHandler

var _score: Score
var _store: ScoreStore
var _bus: TrEventBus


func _init(score: Score, store: ScoreStore, bus: TrEventBus) -> void:
	_score = score
	_store = store
	_bus = bus


func handles() -> Script:
	return AddPoints


func handle(request: TrRequest) -> TrResult:
	var result: TrResult = _score.add((request as AddPoints).amount)
	if result.is_err():
		return result
	var err: Error = _store.save_points(_score.points)
	if err != OK:
		return TrResult.failure(&"save_failed", error_string(err))
	_bus.publish(PointsChanged.new(_score.points))
	return result
