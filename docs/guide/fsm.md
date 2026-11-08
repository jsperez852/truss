# fsm: TrStateMachine and TrState

A hierarchical state machine made of nodes. States are `TrState` children of a `TrStateMachine`; a state with
child states is a parent state. Transitions are requested **by class**: `machine.transition_to(EnemyChase)`.
A misspelled state is a parse error, not a string that silently matches nothing.

```
Enemy (CharacterBody2D)
├─ Shape
└─ StateMachine (TrStateMachine, initial_state = Alive)
   ├─ Alive (EnemyAlive, initial_substate = Wander)   # shared behavior for every living state
   │  ├─ Wander (EnemyWander)
   │  └─ Chase (EnemyChase)
   └─ Dead (EnemyDead)
```

```gdscript
class_name EnemyWander
extends TrState

func physics_update(_delta: float) -> void:
	var enemy := owner as ArenaEnemy
	enemy.velocity = Vector2.RIGHT * enemy.config.enemy_speed
	enemy.move_and_slide()
	if enemy.global_position.distance_to(enemy.target.global_position) < enemy.config.chase_distance:
		machine.transition_to(EnemyChase)
```

## Behavior

| Situation | What happens |
|---|---|
| `_ready()` | Enters `initial_state` (or the first child state), then its `initial_substate` (or first child) down to a leaf |
| Transition between siblings (`Wander → Chase`) | `exit` Wander, `enter` Chase. The parent `Alive` stays active |
| Leaving a parent (`Chase → Dead`) | `exit` Chase, `exit` Alive, `enter` Dead |
| Entering a parent (`Dead → Alive`) | `exit` Dead, `enter` Alive, `enter` its initial substate |
| Transition to the current leaf | `exit` and `enter` it again |
| `transition_to()` from inside `enter()`/`exit()` | Queued, runs right after the current transition |
| `update` / `physics_update` | Every active state, **parent first**, then the leaf |
| `handle_input(event) -> bool` | The leaf first, then parents, until one returns `true` (the event is then marked handled) |

`enter(previous)` receives the leaf that was active before, and `exit(next)` the leaf that will be active.
The `transitioned(from, to)` signal fires after each transition.

## Transition arguments

```gdscript
machine.transition_to(EnemyHurt, {hitstun = 0.3, knockback = Vector2(120, 0)})

# in EnemyHurt
func enter(_previous: TrState) -> void:
	var stun: float = machine.transition_args.get(&"hitstun", 0.2)
```

`transition_args` is set before the `exit`/`enter` calls of a transition and stays until the next transition.
Queued transitions keep their own arguments. Lua-style keys (`{hitstun = 0.3}`) are `StringName`s, and GDScript
dictionaries treat `"hitstun"` and `&"hitstun"` as the same key, so either works with `get()`.

## Intents

Player input and AI can drive the same states with intents instead of `InputEvent`s:

```gdscript
machine.send_intent(&"attack")                 # from the player script or an AI behavior
machine.send_intent(&"move", {direction = Vector2.LEFT})

# in a state
func handle_intent(intent: StringName, data: Dictionary) -> bool:
	if intent == &"attack":
		machine.transition_to(PlayerAttack)
		return true
	return false
```

The active leaf gets it first, then its parents, until one returns `true`. `send_intent` returns whether a state
handled it.

## Inspecting

- `current()`, `active_path()`, `is_in(state)`, `is_in_class(EnemyAlive)`, `find_state(EnemyChase)`.
- `history` keeps the last `history_size` transitions as `"From -> To"`, visible in the remote inspector while the
  game runs.
- `running = false` pauses updates and input without leaving the current state.

## Tips

- Reach the character through `owner` (the scene root) or an `@export`, never with `get_parent().get_parent()`.
- Put state-independent data (health, config) on the character; states only decide behavior.
- Let the `AnimationTree` drive animations, and have states set its parameters.
- Exported state references in a `.tscn` are written as `node_paths=PackedStringArray("initial_state")` on the
  node line plus `initial_state = NodePath("Alive")`; see `examples/arena/features/combat/presentation/enemy.tscn`.
