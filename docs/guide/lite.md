# Truss Lite: adopting Truss in small games

Truss is a set of pieces, not a framework you must buy whole. Full Truss (modules, DI, mediator, `arch_check`)
pays off in mid-sized and large games, and is more code than a small arcade game itself. Pick the level that
matches the game. Every level keeps working when you move to the next one.

| Level | For | Uses | Skips |
|---|---|---|---|
| 1. Arcade | Pong, Flappy-style, game jams | `TrEventBus` in one autoload, `TrResult`, optionally a `TrStateMachine` for the game phase, `Truss.pause` | DI, modules, mediator, plugin settings |
| 2. Mid-size | Platformers, small roguelites, idle games | Level 1 + `TrRegistry` for content, `TrStats` for numbers, pause tokens and lifecycle events | Modules, mediator, `arch_check` |
| 3. Full | Games with many features or several people | Everything: modules, DI and `_inject`, mediator, `arch_check`, generators | Nothing |

## Level 1: arcade

One autoload owns the bus; scripts publish and subscribe to typed events. Saving returns a `TrResult`.

```gdscript
# file: res://game.gd (autoload "Game")
extends Node

var bus := TrEventBus.new()
var best_score: int = 0


func save_best(score: int) -> TrResult:
	if score <= best_score:
		return TrResult.success(false)
	best_score = score
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best_score)
	var err: Error = cfg.save("user://best.cfg")
	return TrResult.success(true) if err == OK else TrResult.failure(&"save_failed", error_string(err))
```

```gdscript
# file: res://events.gd
class_name Events
extends RefCounted

class PlayerDied:
	extends TrEvent

class ScoreChanged:
	extends TrEvent
	var score: int
	func _init(p_score: int = 0) -> void:
		score = p_score
```

```gdscript
# file: res://hud.gd
extends Label


func _ready() -> void:
	Game.bus.subscribe(Events.ScoreChanged, _on_score_changed)


func _exit_tree() -> void:
	Game.bus.unsubscribe_all(self)


func _on_score_changed(event: Events.ScoreChanged) -> void:
	text = "Score: %d" % event.score
```

Publishing: `Game.bus.publish(Events.ScoreChanged.new(score))`. A game phase with three bool flags
(`is_playing`, `is_dead`, `can_restart`) is a good candidate for a small `TrStateMachine` with `Ready`, `Playing` and
`Dead` states (see [fsm](fsm.md)).

Pause without the plugin: `Truss.pause` needs the `Truss` autoload. If you don't enable the plugin, create one
yourself: `var pause := TrPause.new(get_tree())` in `Game._ready()`.

## Level 2: mid-size

Add content and numbers, still without modules:

```gdscript
# file: res://content.gd (autoload "Content")
extends Node

var upgrades := TrRegistry.new(UpgradeDef)
var stats := TrStats.new({&"income": 1.0, &"speed": 1.0})


func _ready() -> void:
	var scan: TrResult = upgrades.scan("res://data/upgrades")
	if scan.is_err():
		push_error(scan.message)


func buy(id: StringName) -> TrResult:
	var def := upgrades.by_id(id) as UpgradeDef
	if def == null:
		return TrResult.failure(&"unknown_upgrade", str(id))
	TrModifierDef.apply_all(def.modifiers, stats, def)
	return TrResult.success(def)
```

```gdscript
# file: res://upgrade_def.gd
class_name UpgradeDef
extends Resource

@export var id: StringName
@export var cost: float = 10.0
@export var modifiers: Array[TrModifierDef] = []
```

- `TrRegistry` loads every `.tres` in a folder and keeps working after export (where `DirAccess` doesn't).
- `TrStats` turns forgotten keys into errors and keeps modifiers by source, so selling an upgrade is `stats.remove_from(def)`.
- Hold a pause token while a menu is open, and react to `TrAppEvents.FocusLost` to save or pause (see [time](time.md)).

## Level 3: full

When features multiply, move the autoload's contents into modules and let nodes receive services with
`_inject`: [modules](modules.md), [di](di.md), [messaging](messaging.md), [tooling](tooling.md). `examples/arena`
is a complete game at this level.

## Signs it's time for the next level

- Several autoloads reach into each other, or one autoload holds most of the game state → level 3.
- The same "load every `.tres` in a folder" or "sum the modifiers" code appears twice → level 2.
- Scenes can't run alone (F6) because they need globals set up by another scene → level 3 with `_inject` and test doubles.
