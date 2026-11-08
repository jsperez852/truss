@abstract class_name FxLogModule
extends TrModule
## Base for test modules: records register/start/stop calls into a shared log.

var log: Array[String]


func _init(p_log: Array[String] = []) -> void:
	log = p_log


func _name() -> String:
	return TrContracts.describe(get_script() as Script)


func register(_c: TrServiceContainer) -> void:
	log.append("register " + _name())


func start(_c: TrServiceContainer) -> void:
	log.append("start " + _name())


func stop(_c: TrServiceContainer) -> void:
	log.append("stop " + _name())
