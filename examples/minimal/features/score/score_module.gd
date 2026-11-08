class_name ScoreModule
extends TrModule


func dependencies() -> Array[Script]:
	return [CoreModule, StorageModule]


func register(c: TrServiceContainer) -> void:
	c.singleton(Score, func() -> Score: return Score.new())


func start(c: TrServiceContainer) -> void:
	var mediator := c.get_service(TrMediator) as TrMediator
	mediator.register(AddPointsHandler.new(
		c.get_service(Score) as Score,
		c.get_service(ScoreStore) as ScoreStore,
		c.get_service(TrEventBus) as TrEventBus))
