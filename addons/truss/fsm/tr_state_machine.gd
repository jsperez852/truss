class_name TrStateMachine
extends Node
## A hierarchical state machine made of [TrState] child nodes. Transitions are requested by state
## [b]class[/b], so a typo is a parse error instead of a silent failure.
## [codeblock]
## Enemy (CharacterBody2D)
## └─ TrStateMachine (initial_state = Alive)
##    ├─ Alive (TrState)            # shared: take damage, die
##    │  ├─ Idle (TrState)
##    │  └─ Chase (TrState)
##    └─ Dead (TrState)
##
## machine.transition_to(EnemyChase)   # exits Idle, enters Chase; Alive stays active
## [/codeblock]
## A transition requested while another one is running (from [method TrState.enter] or [method TrState.exit])
## is queued and runs right after it.
## [br][br]
## Transitions can carry data, read through [member transition_args]:
## [codeblock]
## machine.transition_to(EnemyHurt, {hitstun = 0.3})
## # in EnemyHurt.enter():
## var stun: float = machine.transition_args.get(&"hitstun", 0.2)
## [/codeblock]
## Player input and AI can drive the same states with intents: [code]machine.send_intent(&"attack")[/code]
## reaches [method TrState.handle_intent] of the active leaf first, then its parents.

signal transitioned(from: TrState, to: TrState)

## The state entered on [code]_ready()[/code]. Defaults to the first child state.
@export var initial_state: TrState
## How many transitions [member history] keeps.
@export_range(0, 256) var history_size: int = 32
## Run [method TrState.update], [method TrState.physics_update] and input on the active states.
@export var running: bool = true

## Recent transitions as "From -> To" (state node names), newest last. Visible in the remote inspector.
var history: PackedStringArray = []
## Arguments of the current (or last) transition. Set before [method TrState.exit] and [method TrState.enter]
## run, and kept until the next transition. Keys are read as given ([code]{hitstun = 0.3}[/code] uses the
## StringName-like key [code]"hitstun"[/code]; read it with [code]get(&"hitstun")[/code] or [code]get("hitstun")[/code]).
var transition_args: Dictionary = {}

var _active_path: Array[TrState] = []   # root first, leaf last
var _transitioning: bool = false
var _queued: Array[TrState] = []
var _queued_args: Array[Dictionary] = []


func _ready() -> void:
	for state: TrState in _all_states(self):
		state.machine = self
	var start: TrState = initial_state if initial_state != null else _first_child_state(self)
	if start == null:
		push_error("TrStateMachine %s has no TrState children" % get_path())
		return
	_go(start)


## The active leaf state.
func current() -> TrState:
	if _active_path.is_empty():
		return null
	var leaf: TrState = _active_path.back()
	return leaf


## The active states from the top-level state down to the leaf.
func active_path() -> Array[TrState]:
	return _active_path.duplicate()


## [code]true[/code] when [param state] is the active leaf or one of its parents.
func is_in(state: TrState) -> bool:
	return _active_path.has(state)


## [code]true[/code] when a state of class [param state_class] (or a subclass) is on the active path.
func is_in_class(state_class: Script) -> bool:
	for state: TrState in _active_path:
		if is_instance_of(state, state_class):
			return true
	return false


## Transitions to the state of class [param state_class], with optional [param args] (see
## [member transition_args]). If it's a parent state, its initial substate is entered too. Returns
## [code]false[/code] (and reports an error) when no such state exists.
func transition_to(state_class: Script, args: Dictionary = {}) -> bool:
	var target: TrState = find_state(state_class)
	if target == null:
		push_error("TrStateMachine %s: no state of class %s" % [get_path(), TrContracts.describe(state_class)])
		return false
	return transition_to_state(target, args)


## Transitions to a specific state node of this machine.
func transition_to_state(target: TrState, args: Dictionary = {}) -> bool:
	if target == null or not is_ancestor_of(target):
		push_error("TrStateMachine %s: %s is not one of its states" % [get_path(), str(target)])
		return false
	if _transitioning:
		_queued.append(target)
		_queued_args.append(args)
		return true
	_go(target, args)
	while not _queued.is_empty():
		var next: TrState = _queued.pop_front()
		var next_args: Dictionary = _queued_args.pop_front()
		_go(next, next_args)
	return true


## Sends an intent (an action request such as [code]&"attack"[/code] or [code]&"jump"[/code]) to the active
## leaf state, then to its parents, until one returns [code]true[/code] from [method TrState.handle_intent].
## Returns whether a state handled it.
func send_intent(intent: StringName, data: Dictionary = {}) -> bool:
	for i: int in range(_active_path.size() - 1, -1, -1):
		if _active_path[i].handle_intent(intent, data):
			return true
	return false


## The first state (in tree order) that is an instance of [param state_class].
func find_state(state_class: Script) -> TrState:
	for state: TrState in _all_states(self):
		if is_instance_of(state, state_class):
			return state
	return null


func _go(target: TrState, args: Dictionary = {}) -> void:
	_transitioning = true
	transition_args = args
	var leaf: TrState = target
	var child: TrState = _initial_of(leaf)
	while child != null:
		leaf = child
		child = _initial_of(leaf)
	var new_path: Array[TrState] = _path_to(leaf)
	var previous: TrState = current()
	var shared: int = 0
	while shared < mini(_active_path.size(), new_path.size()) and _active_path[shared] == new_path[shared]:
		shared += 1
	if previous == leaf:
		shared = new_path.size() - 1  # re-entering the same leaf: exit and enter it again
	for i: int in range(_active_path.size() - 1, shared - 1, -1):
		_active_path[i].exit(leaf)
	_active_path = new_path
	for i: int in range(shared, new_path.size()):
		new_path[i].enter(previous)
	if history_size > 0:
		history.append("%s -> %s" % [previous.name if previous != null else "<start>", leaf.name])
		while history.size() > history_size:
			history.remove_at(0)
	_transitioning = false
	transitioned.emit(previous, leaf)


func _initial_of(state: TrState) -> TrState:
	if state.initial_substate != null and state.is_ancestor_of(state.initial_substate):
		return state.initial_substate
	return _first_child_state(state)


func _first_child_state(node: Node) -> TrState:
	for child: Node in node.get_children():
		if child is TrState:
			return child as TrState
	return null


func _path_to(leaf: TrState) -> Array[TrState]:
	var path: Array[TrState] = []
	var node: Node = leaf
	while node != null and node != self:
		if node is TrState:
			path.push_front(node as TrState)
		node = node.get_parent()
	return path


func _all_states(node: Node) -> Array[TrState]:
	var out: Array[TrState] = []
	for child: Node in node.get_children():
		if child is TrState:
			out.append(child as TrState)
			out.append_array(_all_states(child))
	return out


func _process(delta: float) -> void:
	if running:
		for state: TrState in _active_path.duplicate():
			if is_in(state):
				state.update(delta)


func _physics_process(delta: float) -> void:
	if running:
		for state: TrState in _active_path.duplicate():
			if is_in(state):
				state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	for i: int in range(_active_path.size() - 1, -1, -1):
		if _active_path[i].handle_input(event):
			get_viewport().set_input_as_handled()
			return
