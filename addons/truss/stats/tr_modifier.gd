class_name TrModifier
extends RefCounted
## One change applied to a [TrStat]: a flat amount, a percentage or a multiplier, tagged with its source.
##
## [codeblock]
## damage.add(TrModifier.flat(5.0, sword))        # +5
## damage.add(TrModifier.percent(0.2, &"buff"))    # +20 % (percentages add together)
## damage.add(TrModifier.multiply(1.5, rage))      # x1.5 (multipliers multiply)
## [/codeblock]
## The source is any [Object] (an item, a node, an effect) or a [StringName]. Modifiers whose source object was
## freed are dropped automatically.

enum Kind { FLAT, PERCENT, MULTIPLY }

var kind: Kind
var amount: float
var _source_ref: WeakRef
var _source_name: StringName = &""
var _has_object_source: bool = false


func _init(p_kind: Kind = Kind.FLAT, p_amount: float = 0.0, source: Variant = null) -> void:
	kind = p_kind
	amount = p_amount
	if typeof(source) == TYPE_OBJECT and is_instance_valid(source):
		var source_object: Object = source
		_source_ref = weakref(source_object)
		_has_object_source = true
	elif typeof(source) == TYPE_STRING_NAME or typeof(source) == TYPE_STRING:
		_source_name = StringName(str(source))


static func flat(p_amount: float, source: Variant = null) -> TrModifier:
	return TrModifier.new(Kind.FLAT, p_amount, source)


## [param fraction] is a fraction: 0.2 means +20 %. Percentages on the same stat add together.
static func percent(fraction: float, source: Variant = null) -> TrModifier:
	return TrModifier.new(Kind.PERCENT, fraction, source)


static func multiply(factor: float, source: Variant = null) -> TrModifier:
	return TrModifier.new(Kind.MULTIPLY, factor, source)


## [code]true[/code] when the modifier was created with [param source] (same object or same name).
func is_from(source: Variant) -> bool:
	if typeof(source) == TYPE_OBJECT:
		return _has_object_source and is_instance_valid(source) and _source_ref.get_ref() == source
	if typeof(source) == TYPE_STRING_NAME or typeof(source) == TYPE_STRING:
		return _source_name != &"" and _source_name == StringName(str(source))
	return false


## [code]false[/code] when the modifier had a source object that has been freed.
func is_alive() -> bool:
	return not _has_object_source or _source_ref.get_ref() != null


## The source object, its name, or [code]null[/code].
func source() -> Variant:
	if _has_object_source:
		return _source_ref.get_ref()
	return _source_name if _source_name != &"" else null


func _to_string() -> String:
	match kind:
		Kind.FLAT:
			return _signed(amount)
		Kind.PERCENT:
			return _signed(amount * 100.0) + "%"
		_:
			return "x" + format_number(amount)


## Formats a number without a trailing ".0" for whole values (15.0 -> "15", 1.5 -> "1.5").
## GDScript's % operator has no %g, and String.num(15.0) gives "15.0".
static func format_number(number: float) -> String:
	if is_equal_approx(number, roundf(number)) and absf(number) < 1e15:
		return str(int(roundf(number)))
	return String.num(number)


static func _signed(number: float) -> String:
	return ("+" if number >= 0.0 else "") + format_number(number)
