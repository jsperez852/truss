class_name FxDisposable
extends RefCounted

var disposed: int = 0

func dispose() -> void:
	disposed += 1
