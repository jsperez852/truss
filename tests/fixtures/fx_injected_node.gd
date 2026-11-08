class_name FxInjectedNode
extends Node

var log: Array[String] = []
var store: FxStore
var inject_calls: int = 0


func _inject(c: TrServiceContainer) -> void:
	inject_calls += 1
	store = c.get_service(FxStore) as FxStore
	log.append("inject " + name)


func _ready() -> void:
	log.append("ready %s store=%s" % [name, store != null])
