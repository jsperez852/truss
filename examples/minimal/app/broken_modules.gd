class_name BrokenModules
extends RefCounted
## Deliberately broken setups, selected with --break=<mode>, to show how Truss fails.


class CycleA:
	extends TrModule
	func module_name() -> String:
		return "CycleA"
	func dependencies() -> Array[Script]:
		return [CycleB]
	func register(_c: TrServiceContainer) -> void:
		pass


class CycleB:
	extends TrModule
	func module_name() -> String:
		return "CycleB"
	func dependencies() -> Array[Script]:
		return [CycleA]
	func register(_c: TrServiceContainer) -> void:
		pass


class NeedsUnregisteredService:
	extends TrModule
	func module_name() -> String:
		return "NeedsUnregisteredService"
	func register(c: TrServiceContainer) -> void:
		c.transient(AddPointsHandler, func(s: TrServiceContainer) -> AddPointsHandler:
			return AddPointsHandler.new(s.get_service(Score) as Score, s.get_service(ScoreStore) as ScoreStore, null))
