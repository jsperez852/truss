class_name TrPauseToken
extends RefCounted
## A claim on the game's pause, returned by [method TrPause.acquire]. The game stays paused while any token
## is held. Release it with [method release], or let it be freed (for example when the menu holding it closes).

var reason: StringName
var _pause: WeakRef
var _id: int
var _held: bool = true


func _init(pause: TrPause, id: int, p_reason: StringName) -> void:
	_pause = weakref(pause)
	_id = id
	reason = p_reason


## Releases the pause claim. Calling it again does nothing.
func release() -> void:
	if not _held:
		return
	_held = false
	var pause: TrPause = _pause.get_ref() as TrPause
	if pause != null:
		pause._release(_id)


func is_held() -> bool:
	return _held


func _notification(what: int) -> void:
	# During PREDELETE a script can't call its own methods ("base 'null instance'"), so release inline.
	if what == NOTIFICATION_PREDELETE and _held:
		_held = false
		var pause: TrPause = _pause.get_ref() as TrPause
		if pause != null:
			pause._release(_id)
