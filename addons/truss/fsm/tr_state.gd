@abstract class_name TrState
extends Node
## A state of a [TrStateMachine]. States are child nodes of the machine; a state with child states is a
## parent (composite) state, and its children are substates.
##
## Override only what you need. Parent states run before their active child in [method update] and
## [method physics_update], so shared behavior (gravity, timers) goes in the parent. Input goes to the active
## leaf first and bubbles up to its parents until a state returns [code]true[/code].
## [codeblock]
## class_name EnemyChase
## extends TrState
##
## @export var speed: float = 120.0
##
## func physics_update(delta: float) -> void:
##     var enemy := owner as Enemy
##     enemy.velocity = enemy.global_position.direction_to(enemy.target.global_position) * speed
##     if enemy.global_position.distance_to(enemy.target.global_position) < 24.0:
##         machine.transition_to(EnemyAttack)
## [/codeblock]

## For a parent state: the substate entered when this state is entered. Defaults to the first child state.
@export var initial_substate: TrState

## The machine that owns this state. Set before the first [method enter].
var machine: TrStateMachine


## Called when the state becomes active. [param previous] is the leaf state that was active before, or null.
func enter(_previous: TrState) -> void:
	pass


## Called when the state stops being active. [param next] is the leaf state that will be active.
func exit(_next: TrState) -> void:
	pass


## Return [code]true[/code] to stop the event from reaching parent states.
func handle_input(_event: InputEvent) -> bool:
	return false


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


## The parent state, or null for a top-level state.
func parent_state() -> TrState:
	return get_parent() as TrState


## Child states (substates), in tree order.
func substates() -> Array[TrState]:
	var out: Array[TrState] = []
	for child: Node in get_children():
		if child is TrState:
			out.append(child as TrState)
	return out


## [code]true[/code] when this state is on the machine's active path (the active leaf or one of its parents).
func is_active() -> bool:
	return machine != null and machine.is_in(self)
