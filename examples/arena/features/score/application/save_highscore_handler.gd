class_name SaveHighscoreHandler
extends TrRequestHandler
## Asynchronous handler: send it with TrMediator.send_async(). Saves only when this run set a record.

var _board: ScoreBoard
var _store: HighscoreStore


func _init(board: ScoreBoard, store: HighscoreStore) -> void:
	_board = board
	_store = store


func handles() -> Script:
	return SaveHighscore


func handle(_request: TrRequest) -> TrResult:
	if not _board.is_record():
		return TrResult.success(false)
	var err: Error = await _store.save_best(_board.best)
	if err != OK:
		return TrResult.failure(&"save_failed", error_string(err))
	return TrResult.success(true)
