class_name FxBrokenModule
extends FxLogModule
## Registers a service whose dependency nobody registers.


func register(c: TrServiceContainer) -> void:
	super.register(c)
	c.transient(FxService, func(s: TrServiceContainer) -> FxService: return FxService.new(s.get_service(FxStore) as FxStore))
