class_name TrPhases
extends RefCounted
## A phase machine written in code, for game phases that don't need a node per state (menus, rounds,
## Ready → Playing → Over). Phases are names with optional [code]enter[/code], [code]exit[/code] and
## [code]update[/code] callables, all on the script that owns the machine.
## [codeblock]
## var phase := TrPhases.new(&"game")      # the name shows in the editor's Truss debugger tab
##
## func _ready() -> void:
##     phase.add(&"ready")
##     phase.add(&"playing", {enter = _start_spawning})
##     phase.add(&"crashed", {enter = _stop_world, to = [&"over"]})
##     phase.add(&"over", {enter = _show_results})
##     phase.start(&"ready")
##
## func _process(delta: float) -> void:
##     phase.update(delta)
##
## func _on_player_crashed() -> void:
##     phase.go(&"crashed")
## [/codeblock]
## [code]enter[/code] receives the previous phase and [code]exit[/code] the next one, or nothing when the
## callable takes no argument; [code]update[/code] receives [code]delta[/code] or nothing. [code]to[/code] limits
## which phases can follow. Calling [method go] from inside [code]enter[/code] or [code]exit[/code] runs that
## transition right after the current one finishes. Use [TrStateMachine] when states need their own exports,
## nested substates, input handling or physics.

## Emitted after a transition, once the new phase's [code]enter[/code] has run.
signal changed(previous: StringName, current: StringName)

const OPTION_KEYS: PackedStringArray = ["enter", "exit", "update", "to"]

## Shown in the Truss debugger tab (each transition is reported while the game runs from the editor).
var name: StringName


class Phase:
	extends RefCounted
	var enter: Callable
	var exit: Callable
	var update: Callable
	var allowed: Array[StringName] = []


var _phases: Dictionary[StringName, Phase] = {}
var _current: StringName = &""
var _elapsed: float = 0.0
var _busy: bool = false
var _queued: Array[StringName] = []


func _init(p_name: StringName = &"phases") -> void:
	name = p_name


## Declares [param phase_name]. [param options]: [code]enter[/code], [code]exit[/code], [code]update[/code]
## (Callables) and [code]to[/code] (Array of phase names allowed to follow; empty means any).
## Returns [code]false[/code] and reports an error when the phase already exists or an option is invalid.
func add(phase_name: StringName, options: Dictionary = {}) -> bool:
	if phase_name == &"":
		push_error("TrPhases.add(): the phase name is empty")
		return false
	if _phases.has(phase_name):
		push_error("TrPhases.add(): phase %s already exists" % phase_name)
		return false
	var phase := Phase.new()
	for key: Variant in options:
		var key_name: String = str(key)
		if not OPTION_KEYS.has(key_name):
			push_error("TrPhases.add(%s): unknown option %s (valid: %s)" % [phase_name, key_name, ", ".join(OPTION_KEYS)])
			return false
		var value: Variant = options[key]
		if key_name == "to":
			if typeof(value) != TYPE_ARRAY:
				push_error("TrPhases.add(%s): to must be an Array of phase names" % phase_name)
				return false
			var names: Array = value
			for allowed: Variant in names:
				phase.allowed.append(StringName(str(allowed)))
			continue
		if typeof(value) != TYPE_CALLABLE:
			push_error("TrPhases.add(%s): %s must be a Callable" % [phase_name, key_name])
			return false
		var callable: Callable = value
		var arg_count: int = callable.get_argument_count()
		if arg_count > 1:
			push_error("TrPhases.add(%s): %s takes %d arguments (expected one, or none)" % [phase_name, key_name, arg_count])
			return false
		phase.set(key_name, callable)
	_phases[phase_name] = phase
	return true


## Enters [param phase_name] as the first phase (no [code]exit[/code] runs). Returns [code]false[/code] for an
## unknown phase or when the machine already started.
func start(phase_name: StringName) -> bool:
	if _current != &"":
		push_error("TrPhases.start(): already started in %s (use go())" % _current)
		return false
	if not _phases.has(phase_name):
		push_error("TrPhases.start(): unknown phase %s (known: %s)" % [phase_name, _known()])
		return false
	_busy = true
	_current = phase_name
	_elapsed = 0.0
	_call(_phases[phase_name].enter, &"")
	_busy = false
	_report(&"", phase_name)
	changed.emit(&"", phase_name)
	_drain()
	return true


## Moves to [param phase_name]. Returns [code]false[/code] (and does nothing) when the phase is the current one
## or the current phase's [code]to[/code] list doesn't allow it: a normal, silent refusal. Unknown phases and
## calls before [method start] report an error. Called during a transition, it is queued and returns
## [code]true[/code].
func go(phase_name: StringName) -> bool:
	if _current == &"":
		push_error("TrPhases.go(%s): call start() first" % phase_name)
		return false
	if not _phases.has(phase_name):
		push_error("TrPhases.go(): unknown phase %s (known: %s)" % [phase_name, _known()])
		return false
	if _busy:
		_queued.append(phase_name)
		return true
	if not can_go(phase_name):
		return false
	_busy = true
	var previous: StringName = _current
	_call(_phases[previous].exit, phase_name)
	_current = phase_name
	_elapsed = 0.0
	_call(_phases[phase_name].enter, previous)
	_busy = false
	_report(previous, phase_name)
	changed.emit(previous, phase_name)
	_drain()
	return true


## [code]true[/code] when [method go] would accept [param phase_name] now.
func can_go(phase_name: StringName) -> bool:
	if _current == &"" or phase_name == _current or not _phases.has(phase_name):
		return false
	var allowed: Array[StringName] = _phases[_current].allowed
	return allowed.is_empty() or allowed.has(phase_name)


## Runs the current phase's [code]update[/code] and adds [param delta] to [method elapsed].
func update(delta: float) -> void:
	if _current == &"":
		return
	_elapsed += delta
	var callable: Callable = _phases[_current].update
	if not callable.is_valid():
		return
	if callable.get_argument_count() == 0:
		callable.call()
	else:
		callable.call(delta)


## The current phase, or [code]&""[/code] before [method start].
func current() -> StringName:
	return _current


func is_in(phase_name: StringName) -> bool:
	return _current == phase_name


func is_in_any(phase_names: Array[StringName]) -> bool:
	return phase_names.has(_current)


func has(phase_name: StringName) -> bool:
	return _phases.has(phase_name)


## Seconds spent in the current phase, counted by [method update].
func elapsed() -> float:
	return _elapsed


func _call(callable: Callable, other: StringName) -> void:
	if not callable.is_valid():
		return
	if callable.get_argument_count() == 0:
		callable.call()
	else:
		callable.call(other)


func _report(previous: StringName, next: StringName) -> void:
	if EngineDebugger.is_active():
		EngineDebugger.send_message("truss:phase", [String(name), String(previous), String(next), Engine.get_process_frames()])


func _drain() -> void:
	while not _queued.is_empty() and not _busy:
		var next: StringName = _queued.pop_front()
		go(next)


func _known() -> String:
	var names := PackedStringArray()
	for phase_name: StringName in _phases:
		names.append(String(phase_name))
	return ", ".join(names)
