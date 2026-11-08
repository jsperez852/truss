class_name FxNamedEvents
extends RefCounted
## Inner classes used to test Outer.Inner naming.

const PRELOADED: Script = preload("res://tests/fixtures/fx_hit.gd")


class StaminaChanged:
	extends TrEvent
	var value: float = 0.0


class Nested:
	extends RefCounted

	class Deeper:
		extends TrEvent
