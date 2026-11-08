class_name FxService
extends RefCounted

var store: FxStore

func _init(p_store: FxStore = null) -> void:
	store = p_store
