class_name CombatModule
extends TrModule


func dependencies() -> Array[Script]:
	return [CoreModule, GameModule]


func register(c: TrServiceContainer) -> void:
	c.singleton(CombatConfig, func() -> CombatConfig: return CombatConfig.new())
