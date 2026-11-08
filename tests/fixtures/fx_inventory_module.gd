class_name FxInventoryModule
extends FxLogModule


func dependencies() -> Array[Script]:
	return [FxSaveModule]


func register(c: TrServiceContainer) -> void:
	super.register(c)
	c.transient(FxService, func(s: TrServiceContainer) -> FxService: return FxService.new(s.get_service(FxStore) as FxStore))


func start(c: TrServiceContainer) -> void:
	super.start(c)
	log.append("inventory sees store=%d" % (c.get_service(FxService) as FxService).store.value())
