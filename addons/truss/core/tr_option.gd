class_name TrOption
extends RefCounted
## A value that may be absent, without using [code]null[/code] as a signal.
##
## Useful when [code]null[/code] is a valid value, or to make "maybe missing" explicit in an API:
## [codeblock]
## func find_quest(id: StringName) -> TrOption:
##     return TrOption.some(_quests[id]) if _quests.has(id) else TrOption.none()
## [/codeblock]

var _has_value: bool = false
var _value: Variant = null


static func some(present: Variant) -> TrOption:
	var o := TrOption.new()
	o._has_value = true
	o._value = present
	return o


static func none() -> TrOption:
	return TrOption.new()


func is_some() -> bool:
	return _has_value


func is_none() -> bool:
	return not _has_value


## Returns the value. Calling it on [method none] is a programming error: it reports it and returns [code]null[/code].
func unwrap() -> Variant:
	if not _has_value:
		push_error("TrOption.unwrap() called on none()")
	return _value


func unwrap_or(default: Variant) -> Variant:
	return _value if _has_value else default


## Converts to a [TrResult]: success with the value, or failure with [param error_code].
func ok_or(error_code: StringName, text: String = "") -> TrResult:
	return TrResult.success(_value) if _has_value else TrResult.failure(error_code, text)


func _to_string() -> String:
	return "TrOption.some(%s)" % str(_value) if _has_value else "TrOption.none()"
