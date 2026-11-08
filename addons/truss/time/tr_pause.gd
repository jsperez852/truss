class_name TrPause
extends RefCounted
## Pause with tokens, and hit stop. Available as [code]Truss.pause[/code].
##
## [codeblock]
## var token: TrPauseToken = Truss.pause.acquire(&"inventory_menu")   # paused while any token is held
## token.release()                                                     # or let the token be freed
## Truss.pause.hit_stop(0.08)                                          # 80 ms at 5 % speed, then restore
## [/codeblock]
## The game stays paused while at least one token is held, so closing one menu can't unpause the game under
## another. When the last token is released, the pause state from before the first token is restored, so code
## that still sets [member SceneTree.paused] directly isn't overridden.
## [br][br]
## Hit stop changes [member Engine.time_scale], not [member SceneTree.paused]: UI, particles and audio keep
## running. Overlapping hit stops keep the lowest scale until the last one ends. The timer ignores the time
## scale (measured within one frame of the requested time on Godot 4.5.1 and 4.7.2).

## Emitted when the paused state managed by tokens changes.
signal changed(paused: bool)

var _tree: SceneTree
var _target: Object
var _tokens: Dictionary[int, StringName] = {}
var _next_id: int = 1
var _paused_before: bool = false
var _hit_stops: Dictionary[int, float] = {}
var _next_hit: int = 1
var _scale_before: float = 1.0


## [param tree] provides timers. [param target] is the object whose [code]paused[/code] property is managed
## (defaults to [param tree]; tests pass a stand-in object).
func _init(tree: SceneTree, target: Object = null) -> void:
	_tree = tree
	_target = target if target != null else tree


## Pauses the game until the returned token is released or freed. [param reason] shows in [method holders].
func acquire(reason: StringName) -> TrPauseToken:
	if _tokens.is_empty():
		_paused_before = _is_target_paused()
	var id: int = _next_id
	_next_id += 1
	_tokens[id] = reason
	_apply()
	return TrPauseToken.new(self, id, reason)


func is_paused() -> bool:
	return not _tokens.is_empty()


## Reasons of the tokens currently held (one entry per token).
func holders() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_tokens.values())
	return out


## Slows the game to [param scale] for [param seconds] of real time, then restores the previous time scale.
func hit_stop(seconds: float, scale: float = 0.05) -> void:
	if seconds <= 0.0:
		return
	if _hit_stops.is_empty():
		_scale_before = Engine.time_scale
	var id: int = _next_hit
	_next_hit += 1
	_hit_stops[id] = clampf(scale, 0.0, 1.0) * _scale_before
	_apply_time_scale()
	var timer: SceneTreeTimer = _tree.create_timer(seconds, true, false, true)
	timer.timeout.connect(_end_hit_stop.bind(id))


func is_hit_stopping() -> bool:
	return not _hit_stops.is_empty()


## Releases every token and ends every hit stop (for scene changes or shutdown).
func reset() -> void:
	var had_tokens: bool = not _tokens.is_empty()
	_tokens.clear()
	if had_tokens:
		_set_target_paused(_paused_before)
		changed.emit(false)
	if not _hit_stops.is_empty():
		_hit_stops.clear()
		Engine.time_scale = _scale_before


func _release(id: int) -> void:
	if not _tokens.has(id):
		return
	_tokens.erase(id)
	_apply()


func _apply() -> void:
	var was: bool = _is_target_paused()
	var now: bool = true if not _tokens.is_empty() else _paused_before
	_set_target_paused(now)
	if was != now:
		changed.emit(not _tokens.is_empty())


func _end_hit_stop(id: int) -> void:
	_hit_stops.erase(id)
	_apply_time_scale()


func _apply_time_scale() -> void:
	if _hit_stops.is_empty():
		Engine.time_scale = _scale_before
		return
	var lowest: float = INF
	for scale: float in _hit_stops.values():
		lowest = minf(lowest, scale)
	Engine.time_scale = lowest


func _is_target_paused() -> bool:
	var value: bool = _target.get(&"paused")
	return value


func _set_target_paused(value: bool) -> void:
	_target.set(&"paused", value)
