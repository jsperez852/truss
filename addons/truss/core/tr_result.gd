class_name TrResult
extends RefCounted
## The outcome of an operation that can fail in an expected way.
##
## Use it for errors the game must handle (not enough gold, inventory full, save slot empty).
## Programming errors still use [method @GlobalScope.push_error] and [code]assert()[/code].
## [codeblock]
## var r: TrResult = inventory.add(item, 1)
## if r.is_err():
##     show_message(r.message)
##     return
## var added: int = r.value
## [/codeblock]

## [code]true[/code] when the operation succeeded.
var ok: bool = false
## The produced value (any type). [code]null[/code] for failures.
var value: Variant = null
## A short machine-readable code such as [code]&"inventory_full"[/code]. Empty for successes.
var error: StringName = &""
## A human-readable explanation of the failure.
var message: String = ""


## Creates a successful result holding [param result_value].
static func success(result_value: Variant = null) -> TrResult:
	var r := TrResult.new()
	r.ok = true
	r.value = result_value
	return r


## Creates a failed result with an error [param code] and an optional [param text].
static func failure(code: StringName, text: String = "") -> TrResult:
	assert(code != &"", "TrResult.failure() needs a non-empty error code")
	var r := TrResult.new()
	r.ok = false
	r.error = code
	r.message = text
	return r


func is_ok() -> bool:
	return ok


func is_err() -> bool:
	return not ok


## Returns the value. Calling it on a failure is a programming error: it reports it and returns [code]null[/code].
func unwrap() -> Variant:
	if not ok:
		push_error("TrResult.unwrap() called on a failure: %s" % self)
		return null
	return value


## Returns the value, or [param default] when this is a failure.
func unwrap_or(default: Variant) -> Variant:
	return value if ok else default


## On success, returns a new success holding [code]transform.call(value)[/code]. Failures pass through unchanged.
func map(transform: Callable) -> TrResult:
	if not ok:
		return self
	return TrResult.success(transform.call(value))


## On success, calls [param next] with the value; it must return a [TrResult]. Failures pass through unchanged.
func and_then(next: Callable) -> TrResult:
	if not ok:
		return self
	var produced: Variant = next.call(value)
	if produced is TrResult:
		return produced as TrResult
	push_error("TrResult.and_then(): the callable must return a TrResult, got %s" % type_string(typeof(produced)))
	return TrResult.failure(&"invalid_result", "and_then callable did not return a TrResult")


func _to_string() -> String:
	if ok:
		return "TrResult.success(%s)" % str(value)
	return "TrResult.failure(%s%s)" % [error, (", \"%s\"" % message) if not message.is_empty() else ""]
