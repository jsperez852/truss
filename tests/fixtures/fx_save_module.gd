class_name FxSaveModule
extends FxLogModule


func register(c: TrServiceContainer) -> void:
	super.register(c)
	c.singleton(FxStore, func() -> FxStore: return FxMemoryStore.new())
