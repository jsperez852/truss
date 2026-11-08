class_name ScoreModule
extends TrModule

var _tracker: ScoreTracker


func dependencies() -> Array[Script]:
	return [CoreModule, CombatModule]


func register(c: TrServiceContainer) -> void:
	c.singleton(HighscoreStore, func() -> HighscoreStore: return SaveHighscoreStore.new("user://arena.save"))
	c.singleton(ScoreBoard, func(s: TrServiceContainer) -> ScoreBoard:
		return ScoreBoard.new((s.get_service(HighscoreStore) as HighscoreStore).load_best()))


func start(c: TrServiceContainer) -> void:
	var board := c.get_service(ScoreBoard) as ScoreBoard
	var bus := c.get_service(TrEventBus) as TrEventBus
	_tracker = ScoreTracker.new(board, bus)
	(c.get_service(TrMediator) as TrMediator).register(SaveHighscoreHandler.new(board, c.get_service(HighscoreStore) as HighscoreStore))
