class_name WavesModule
extends TrModule

var _tracker: WaveTracker


func dependencies() -> Array[Script]:
	return [CoreModule, CombatModule]


func register(c: TrServiceContainer) -> void:
	c.singleton(WavePlan, func() -> WavePlan: return WavePlan.new())
	c.singleton(WaveProgress, func() -> WaveProgress: return WaveProgress.new())


func start(c: TrServiceContainer) -> void:
	var progress := c.get_service(WaveProgress) as WaveProgress
	var plan := c.get_service(WavePlan) as WavePlan
	var bus := c.get_service(TrEventBus) as TrEventBus
	(c.get_service(TrMediator) as TrMediator).register(StartNextWaveHandler.new(progress, plan, bus))
	_tracker = WaveTracker.new(progress, plan, bus)
