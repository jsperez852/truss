class_name StorageModule
extends TrModule


func register(c: TrServiceContainer) -> void:
	c.singleton(ScoreStore, func() -> ScoreStore: return MemoryScoreStore.new())
