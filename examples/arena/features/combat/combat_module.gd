class_name CombatModule
extends TrModule


func dependencies() -> Array[Script]:
	return [CoreModule, GameModule]


func register(c: TrServiceContainer) -> void:
	c.singleton(CombatConfig, func() -> CombatConfig: return CombatConfig.new())
	c.singleton(PlayerStats, func() -> PlayerStats: return PlayerStats.new())
	c.singleton(EnemyTypes, func() -> EnemyTypes:
		var types := EnemyTypes.new()
		var scan: TrResult = types.scan(EnemyTypes.FOLDER)
		if scan.is_err():
			push_error(scan.message)
		return types)


func start(c: TrServiceContainer) -> void:
	# Every cleared wave makes the player fire 15 % faster.
	var stats := c.get_service(PlayerStats) as PlayerStats
	(c.get_service(TrEventBus) as TrEventBus).subscribe(WaveCleared, func(event: WaveCleared) -> void:
		stats.add(&"fire_interval", TrModifier.percent(-0.15, StringName("wave_%d" % event.wave))))
