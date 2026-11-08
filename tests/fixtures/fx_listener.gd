class_name FxListener
extends RefCounted

var received: Array[String] = []

func on_hit(event: FxHit) -> void:
	received.append("hit:%d" % event.damage)

func on_any(event: FxEvent) -> void:
	received.append("any:" + TrContracts.describe_value(event))
