class_name CoreModule
extends TrModule
## Shared messaging services.


func register(c: TrServiceContainer) -> void:
	c.singleton(TrEventBus, func() -> TrEventBus: return TrEventBus.new())
	c.singleton(TrMediator, func() -> TrMediator: return TrMediator.new())
