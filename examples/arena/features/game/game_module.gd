class_name GameModule
extends TrModule

var _options: GameOptions


func _init(options: GameOptions) -> void:
	_options = options


func dependencies() -> Array[Script]:
	return [CoreModule]


func register(c: TrServiceContainer) -> void:
	c.instance(GameOptions, _options)
