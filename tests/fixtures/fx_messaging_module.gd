class_name FxMessagingModule
extends TrModule


func register(c: TrServiceContainer) -> void:
	c.singleton(TrEventBus, func() -> TrEventBus: return TrEventBus.new())
	c.singleton(TrMediator, func() -> TrMediator: return TrMediator.new())


func start(c: TrServiceContainer) -> void:
	var mediator := c.get_service(TrMediator) as TrMediator
	mediator.register(FxAddHandler.new())
	mediator.register(FxAsyncHandler.new())
