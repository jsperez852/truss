# messaging: events, commands and queries

## TrEvent and TrEventBus

Events are classes. The class is the topic, handlers get typed data, and a misspelled event name is a parse error.

```gdscript
class_name EnemyDied
extends TrEvent

var enemy_type: StringName

func _init(type: StringName) -> void:
	enemy_type = type
```

```gdscript
var bus := TrEventBus.new()          # usually registered as a singleton in the container
bus.subscribe(EnemyDied, _on_enemy_died)
bus.publish(EnemyDied.new(&"slime"))

func _on_enemy_died(event: EnemyDied) -> void:
	kills += 1

func _exit_tree() -> void:
	bus.unsubscribe_all(self)
```

- Subscribing to a base event class also receives its subclasses (subclass handlers run first).
- Subscribing the same callable twice has no effect. Only `TrEvent` subclasses are accepted.
- Handlers whose object was freed are dropped automatically. Still unsubscribe in `_exit_tree()` so a node
  removed from the tree (but not freed) stops receiving events.
- Unsubscribing during `publish()` takes effect immediately; subscribing during `publish()` applies from the next event.
- `publish()` returns how many handlers ran.

Use local signals between nodes that share a parent. The bus is for facts that unrelated systems care about
(achievements, audio, analytics, UI). Godot signals don't check their typed parameters on `emit()`; event classes do.

## TrRequest, TrRequestHandler, TrMediator

Commands ("do this") and queries ("tell me this") are `TrRequest` subclasses. Each request class has exactly one
handler.

```gdscript
class_name AddItemRequest
extends TrRequest

var item: ItemDef
var amount: int

func _init(p_item: ItemDef, p_amount: int) -> void:
	item = p_item
	amount = p_amount
```

```gdscript
class_name AddItemHandler
extends TrRequestHandler

var _inventory: Inventory

func _init(inventory: Inventory) -> void:
	_inventory = inventory

func handles() -> Script:
	return AddItemRequest

func handle(request: TrRequest) -> TrResult:
	var r := request as AddItemRequest
	return _inventory.add(r.item, r.amount)
```

```gdscript
var mediator := TrMediator.new()
mediator.register(AddItemHandler.new(inventory))
var result: TrResult = mediator.send(AddItemRequest.new(potion, 1))
```

- `register()` rejects a second handler for the same request class and handlers whose `handles()` isn't a `TrRequest`.
- `send()` with no handler, or a handler that returns `null`, reports an error and returns a failure
  (`no_handler`, `invalid_result`).
- Handlers are synchronous in this version. `send_async` for handlers that `await` is planned for M4.

## TrBehavior: the pipeline

Behaviors wrap every `send()`, like MediatR pipeline behaviors. The first one added is the outermost.

```gdscript
class_name LogRequests
extends TrBehavior

func process(request: TrRequest, next: Callable) -> TrResult:
	var started: int = Time.get_ticks_usec()
	var result: TrResult = next.call()
	print("%s -> %s in %d µs" % [TrContracts.describe_value(request), result, Time.get_ticks_usec() - started])
	return result
```

Return without calling `next` to stop the pipeline (validation, permissions, a paused game). Behaviors are the
place for undo history, replays and analytics, without touching the handlers.

## Cost

See [benchmarks](../benchmarks.md). Route player and AI actions through the mediator, not per-frame movement.
