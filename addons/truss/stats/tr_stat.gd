class_name TrStat
extends RefCounted
## A numeric value made of a base and stacked [TrModifier]s.
##
## [code]value = clamp((base + Σ flat) × (1 + Σ percent) × Π multiply, min_value, max_value)[/code]
## [codeblock]
## var damage := TrStat.new(10.0)
## damage.add(TrModifier.flat(5.0, sword))
## damage.add(TrModifier.percent(0.2, &"buff"))
## damage.add(TrModifier.multiply(1.5, rage))
## damage.value                      # (10 + 5) x 1.2 x 1.5 = 27.0
## damage.remove_from(&"buff")       # 22.5
## [/codeblock]
## The value is recomputed when the base, the limits or the modifiers change, and [signal changed] is emitted
## only when the result is different. Modifiers whose source object was freed are dropped the next time the
## value is read, modified or [method refresh]ed.

## Emitted when [member value] changes.
signal changed(old_value: float, new_value: float)

var base: float:
	set(v):
		base = v
		_recompute()

var min_value: float = -INF:
	set(v):
		min_value = v
		_recompute()

var max_value: float = INF:
	set(v):
		max_value = v
		_recompute()

## The current value (read-only).
var value: float:
	get:
		if _object_sources > 0:
			_prune()
		return _value
	set(_v):
		push_error("TrStat.value is read-only; change base or add a modifier")

var _modifiers: Array[TrModifier] = []
var _value: float = 0.0
var _object_sources: int = 0


func _init(p_base: float = 0.0, p_min: float = -INF, p_max: float = INF) -> void:
	min_value = p_min
	max_value = p_max
	base = p_base


## Adds [param modifier] and returns it, so it can be removed later with [method remove].
func add(modifier: TrModifier) -> TrModifier:
	if modifier == null:
		push_error("TrStat.add(): modifier is null")
		return null
	_modifiers.append(modifier)
	if modifier._has_object_source:
		_object_sources += 1
	_recompute()
	return modifier


## Removes one modifier. Returns [code]false[/code] if it wasn't on this stat.
func remove(modifier: TrModifier) -> bool:
	var index: int = _modifiers.find(modifier)
	if index < 0:
		return false
	_remove_at(index)
	_recompute()
	return true


## Removes every modifier from [param source] (object or name). Returns how many were removed.
func remove_from(source: Variant) -> int:
	var removed: int = 0
	for i: int in range(_modifiers.size() - 1, -1, -1):
		if _modifiers[i].is_from(source):
			_remove_at(i)
			removed += 1
	if removed > 0:
		_recompute()
	return removed


func clear_modifiers() -> void:
	_modifiers.clear()
	_object_sources = 0
	_recompute()


## A copy of the current modifiers.
func modifiers() -> Array[TrModifier]:
	return _modifiers.duplicate()


## Drops modifiers whose source was freed and recomputes. Reading [member value] does this too.
func refresh() -> void:
	_prune()


func _prune() -> void:
	var removed: bool = false
	for i: int in range(_modifiers.size() - 1, -1, -1):
		if not _modifiers[i].is_alive():
			_remove_at(i)
			removed = true
	if removed:
		_recompute()


func _remove_at(index: int) -> void:
	if _modifiers[index]._has_object_source:
		_object_sources -= 1
	_modifiers.remove_at(index)


func _recompute() -> void:
	var flat: float = 0.0
	var percent: float = 0.0
	var factor: float = 1.0
	for m: TrModifier in _modifiers:
		if not m.is_alive():
			continue
		match m.kind:
			TrModifier.Kind.FLAT:
				flat += m.amount
			TrModifier.Kind.PERCENT:
				percent += m.amount
			TrModifier.Kind.MULTIPLY:
				factor *= m.amount
	var result: float = clampf((base + flat) * (1.0 + percent) * factor, min_value, max_value)
	if not is_equal_approx(result, _value):
		var old: float = _value
		_value = result
		changed.emit(old, result)
	else:
		_value = result


func _to_string() -> String:
	return "TrStat(%s, base %s, %d modifiers)" % [TrModifier.format_number(_value), TrModifier.format_number(base), _modifiers.size()]
