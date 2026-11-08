# modules: TrModule, TrBootstrap and the Truss autoload

A **module** is a feature's entry point: it declares which modules it needs and registers that feature's services.
The **bootstrap** is the composition root: it orders modules by dependency, registers them, validates the container
and starts them. If anything is wrong, it fails **before starting anything**, with a message that names the problem.

## Writing a module

```gdscript
class_name ScoreModule
extends TrModule

func dependencies() -> Array[Script]:
	return [CoreModule, StorageModule]

func register(c: TrServiceContainer) -> void:
	c.singleton(Score, func() -> Score: return Score.new())

func start(c: TrServiceContainer) -> void:
	var mediator := c.get_service(TrMediator) as TrMediator
	mediator.register(AddPointsHandler.new(
		c.get_service(Score) as Score,
		c.get_service(ScoreStore) as ScoreStore,
		c.get_service(TrEventBus) as TrEventBus))
```

| Method | When it runs | Rule |
|---|---|---|
| `dependencies()` | Before anything | Return the module **scripts** this one needs |
| `register(c)` | In dependency order | Only register. Other modules may not have registered yet, so don't resolve |
| `start(c)` | After every module registered and `validate()` passed | Resolve services, register handlers, subscribe to events |
| `stop(c)` | On shutdown, in reverse start order | Release what `start` acquired |
| `module_name()` | In messages | Defaults to the `class_name`. Override it in inner classes (`class Foo:` inside a script), which Godot can't name |

## Booting

```gdscript
var boot := TrBootstrap.new()
boot.add(CoreModule.new()).add(StorageModule.new()).add(ScoreModule.new())
var result: TrResult = boot.boot()   # success holds the container
```

Modules can be added in any order: dependencies come first, and otherwise the order you added them is kept.
`boot()` returns a failure, without calling any `start()`, when:

| `error` | Example message |
|---|---|
| `missing_dependency` | `ScoreModule depends on StorageModule, which was not added` |
| `module_cycle` | `module dependency cycle: CycleA -> CycleB -> CycleA` |
| `duplicate_module` | `module added twice: StorageModule` |
| `invalid_container` | `container validation failed:` followed by every problem `validate()` found |
| `already_booted` | `TrBootstrap.boot() was already called` |

`shutdown()` calls `stop()` in reverse order and disposes the container. Pass your own container to
`TrBootstrap.new(container)` to pre-register test doubles.

## The Truss autoload and automatic injection

Enabling the Truss plugin (Project → Project Settings → Plugins) adds a `Truss` autoload and the
`truss/injection/automatic` project setting (default `true`).

Boot from your own composition root, an autoload listed **after** `Truss`. Autoloads are ready before the main
scene is added, so by the time the main scene's nodes enter the tree the container exists, and each node gets
`_inject()` before its `_ready()`:

```gdscript
# res://app/app.gd, autoload "App" (below "Truss" in the autoload list)
extends Node

func _ready() -> void:
	var result: TrResult = Truss.boot([CoreModule.new(), StorageModule.new(), ScoreModule.new()])
	if result.is_err():
		printerr("BOOT FAILED [%s]\n%s" % [result.error, result.message])
		get_tree().quit(1)
```

```gdscript
# Any node in any scene
extends Label

var _mediator: TrMediator

func _inject(c: TrServiceContainer) -> void:
	_mediator = c.get_service(TrMediator) as TrMediator

func _ready() -> void:
	_mediator.send(AddPoints.new(5))
```

| Member | Meaning |
|---|---|
| `Truss.boot(modules: Array) -> TrResult` | Boots with a new `TrBootstrap`; on success starts automatic injection and injects nodes already in the tree |
| `Truss.container` | The application container (after a successful boot) |
| `Truss.injector` | The `TrInjector`. With automatic injection off, call `Truss.injector.inject(node)` yourself |
| `Truss.shutdown()` | Stops modules and disposes the container. Runs automatically when the game quits |

The injector uses `SceneTree.node_added`, which Godot emits after `_enter_tree()` and before `_ready()`,
parent before children (verified on Godot 4.5.1 and 4.7.2). Each node is injected once, even if it leaves and
re-enters the tree. `injector.set_container(scope)` makes new nodes receive a child scope, for example per level.

## Example

[examples/minimal](../../examples/minimal) has a score feature split into domain, application (port, request,
handler, event), infrastructure and presentation, three modules, and an `App` composition root. Run every mode
with `GODOT=/path/to/godot tools/run_example.sh`:

```
PASS normal (exit 0)
PASS cycle (exit 1)
PASS missing-module (exit 1)
PASS missing-registration (exit 1)
```

## The Truss debugger tab

With the plugin enabled, the editor's **Debugger** panel gets a **Truss** tab while the game runs from the editor.
It shows the booted modules and every container registration with its lifetime, and logs the last 200 events
published on the container's `TrEventBus` and requests sent through its `TrMediator` (result, error and time in µs).
Events appear in the order they were published. A request is logged when it finishes, so the events its handler
published appear just before it.
The game side is `TrDebugReporter`, which the `Truss` autoload starts only when `EngineDebugger.is_active()`, so
exported games don't send anything. It adds one behavior to the mediator and one signal connection to the bus.
