class_name TrCurve
extends Resource
## A value that grows with a level: upgrade costs, income per level, enemy health per wave. Authored in the
## inspector, so designers tune numbers without touching code.
## [codeblock]
## # Idle-style cost: ×1.3 per level, rounded up at every level, ×3 every 25 levels.
## var cost := TrCurve.exponential(3.0, 1.3)
## cost.rounding = TrCurve.Rounding.CEIL
## cost.round_each_level = true
## cost.milestone_every = 25
## cost.milestone_multiplier = 3.0
##
## cost.value_at(10)                 # cost of the 11th upgrade
## cost.total(level, 10)             # cost of buying 10 levels at once
## cost.max_affordable(level, coins) # "buy max"
## [/codeblock]
## [b]Closed form[/b] ([member round_each_level] off): [code]base · rate^level[/code] (exponential) or
## [code]base + rate · level[/code] (linear), times [code]milestone_multiplier^(level / milestone_every)[/code],
## rounded once. [b]Per level[/b] ([member round_each_level] on): each level is computed from the previous rounded
## value, which is how most hand-written idle formulas behave ([code]cost = ceil(cost * 1.3)[/code]).

enum Growth { EXPONENTIAL, LINEAR, TABLE }
enum Rounding { NONE, FLOOR, CEIL, ROUND }

## How the value grows from one level to the next.
@export var growth: Growth = Growth.EXPONENTIAL:
	set(value):
		growth = value
		_invalidate()
## Value at level 0.
@export var base: float = 1.0:
	set(value):
		base = value
		_invalidate()
## Exponential: multiplier per level. Linear: amount added per level. Ignored by tables.
@export var rate: float = 1.0:
	set(value):
		rate = value
		_invalidate()
@export var rounding: Rounding = Rounding.NONE:
	set(value):
		rounding = value
		_invalidate()
## Round the value at every level and grow from the rounded value (iterative formulas), instead of rounding once.
@export var round_each_level: bool = false:
	set(value):
		round_each_level = value
		_invalidate()
@export_group("Milestones")
## Every this many levels the value is multiplied by [member milestone_multiplier] (0 = no milestones).
@export var milestone_every: int = 0:
	set(value):
		milestone_every = maxi(value, 0)
		_invalidate()
@export var milestone_multiplier: float = 1.0:
	set(value):
		milestone_multiplier = value
		_invalidate()
@export_group("Table")
## Growth.TABLE: the value of each level; levels past the end use the last value.
@export var table: PackedFloat64Array = PackedFloat64Array():
	set(value):
		table = value
		_invalidate()
@export_group("Limits")
## Values are clamped to [member min_value], [member max_value].
@export var min_value: float = -INF
@export var max_value: float = INF

var _steps: PackedFloat64Array = PackedFloat64Array()


static func exponential(p_base: float, p_rate: float) -> TrCurve:
	var curve := TrCurve.new()
	curve.growth = Growth.EXPONENTIAL
	curve.base = p_base
	curve.rate = p_rate
	return curve


static func linear(p_base: float, per_level: float) -> TrCurve:
	var curve := TrCurve.new()
	curve.growth = Growth.LINEAR
	curve.base = p_base
	curve.rate = per_level
	return curve


static func from_table(values: PackedFloat64Array) -> TrCurve:
	var curve := TrCurve.new()
	curve.growth = Growth.TABLE
	curve.table = values
	return curve


## The value at [param level] (levels below 0 count as 0).
func value_at(level: int) -> float:
	var at: int = maxi(level, 0)
	var value: float
	if growth == Growth.TABLE:
		value = _table_value(at)
	elif round_each_level:
		value = _stepped(at)
	else:
		value = _round(_closed(at))
	return clampf(value, min_value, max_value)


## Sum of [param count] consecutive levels starting at [param from_level]: the price of buying several levels.
func total(from_level: int, count: int) -> float:
	var sum: float = 0.0
	for i: int in maxi(count, 0):
		sum += value_at(from_level + i)
	return sum


## How many consecutive levels starting at [param from_level] fit in [param budget] (at most [param limit]).
func max_affordable(from_level: int, budget: float, limit: int = 1000) -> int:
	var spent: float = 0.0
	var count: int = 0
	while count < limit:
		var next: float = value_at(from_level + count)
		if spent + next > budget:
			break
		spent += next
		count += 1
	return count


func _closed(level: int) -> float:
	var value: float = base * pow(rate, level) if growth == Growth.EXPONENTIAL else base + rate * level
	if milestone_every > 0:
		value *= pow(milestone_multiplier, floori(float(level) / milestone_every))
	return value


func _stepped(level: int) -> float:
	if _steps.is_empty():
		_steps.append(_round(base))
	while _steps.size() <= level:
		var previous: float = _steps[_steps.size() - 1]
		var next_level: int = _steps.size()
		var value: float = _round(previous * rate if growth == Growth.EXPONENTIAL else previous + rate)
		if milestone_every > 0 and next_level % milestone_every == 0:
			value *= milestone_multiplier
		_steps.append(value)
	return _steps[level]


func _table_value(level: int) -> float:
	if table.is_empty():
		return 0.0
	return _round(table[mini(level, table.size() - 1)])


func _round(value: float) -> float:
	match rounding:
		Rounding.FLOOR:
			return floorf(value)
		Rounding.CEIL:
			return ceilf(value)
		Rounding.ROUND:
			return roundf(value)
	return value


func _invalidate() -> void:
	_steps.clear()
	emit_changed()
