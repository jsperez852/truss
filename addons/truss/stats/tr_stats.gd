class_name TrStats
extends RefCounted
## A set of named [TrStat]s with declared keys. Reading or modifying an undeclared stat is an error, so a
## missing key can't silently read as 0.
##
## [codeblock]
## var stats := TrStats.new({&"speed": 220.0, &"damage": 10.0, &"max_health": 100.0})
## stats.add(&"damage", TrModifier.percent(0.25, item))
## stats.value(&"damage")             # 12.5
## stats.remove_from(item)            # removes the item's modifiers from every stat
## stats.changed.connect(func(stat: StringName, old: float, new: float) -> void: print(stat, " ", new))
## [/codeblock]

## Emitted when any stat's value changes.
signal changed(stat: StringName, old_value: float, new_value: float)

var _stats: Dictionary[StringName, TrStat] = {}


## [param defaults]: stat name -> base value. Use [method declare] for limits.
func _init(defaults: Dictionary = {}) -> void:
	for key: Variant in defaults:
		var base_value: float = defaults[key]
		declare(StringName(str(key)), base_value)


## Declares a stat (or redeclares its base and limits) and returns it.
func declare(stat_name: StringName, base_value: float, min_value: float = -INF, max_value: float = INF) -> TrStat:
	if _stats.has(stat_name):
		var existing: TrStat = _stats[stat_name]
		existing.min_value = min_value
		existing.max_value = max_value
		existing.base = base_value
		return existing
	var stat := TrStat.new(base_value, min_value, max_value)
	stat.changed.connect(_on_stat_changed.bind(stat_name))
	_stats[stat_name] = stat
	return stat


func has(stat_name: StringName) -> bool:
	return _stats.has(stat_name)


func names() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_stats.keys())
	return out


## The [TrStat] named [param stat_name]. Reports an error and returns [code]null[/code] if it wasn't declared.
func stat(stat_name: StringName) -> TrStat:
	if not _stats.has(stat_name):
		_unknown(stat_name)
		return null
	return _stats[stat_name]


## The current value. Reports an error and returns 0.0 if the stat wasn't declared.
func value(stat_name: StringName) -> float:
	var s: TrStat = stat(stat_name)
	return s.value if s != null else 0.0


func set_base(stat_name: StringName, base_value: float) -> void:
	var s: TrStat = stat(stat_name)
	if s != null:
		s.base = base_value


## Adds [param modifier] to [param stat_name] and returns it ([code]null[/code] for undeclared stats).
func add(stat_name: StringName, modifier: TrModifier) -> TrModifier:
	var s: TrStat = stat(stat_name)
	return s.add(modifier) if s != null else null


## Removes every modifier from [param source] on every stat. Returns how many were removed.
func remove_from(source: Variant) -> int:
	var removed: int = 0
	for s: TrStat in _stats.values():
		removed += s.remove_from(source)
	return removed


## Current values as a Dictionary (for saving, debugging or UI).
func snapshot() -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	for key: StringName in _stats:
		out[key] = _stats[key].value
	return out


func _unknown(stat_name: StringName) -> void:
	var declared := PackedStringArray()
	for key: StringName in _stats:
		declared.append(String(key))
	declared.sort()
	push_error("TrStats: unknown stat %s (declared: %s)" % [stat_name, ", ".join(declared)])


func _on_stat_changed(old_value: float, new_value: float, stat_name: StringName) -> void:
	changed.emit(stat_name, old_value, new_value)
