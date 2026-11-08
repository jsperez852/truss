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

bus.subscribe(PlayerDied, _on_player_died)

func _on_player_died() -> void:        # no event argument when the handler doesn't need it
	lives -= 1
```

- Subscribing to a base event class also receives its subclasses.
- Subscribing the same callable twice has no effect. Only `TrEvent` subclasses are accepted.
- A handler takes the event as its only argument, or no argument. Handlers with two or more arguments are rejected.
- Handlers whose object was freed are dropped automatically, so `queue_free()` is enough: no `_exit_tree()`
  unsubscribe. Handlers bound to a node are skipped while the node is outside the tree (removed, pooled, being
  reparented) and resume when it comes back. Pass `{outside_tree = true}` to deliver anyway.
  `unsubscribe_all(self)` is still there to stop listening while staying in the tree.
- Unsubscribing during `publish()` takes effect immediately; subscribing during `publish()` applies from the next event.
- `publish()` returns how many handlers ran.

### Priority and source

```gdscript
bus.subscribe(EnemyKilled, _count_points, {priority = 10})    # runs before priority-0 handlers
bus.subscribe(Damaged, _on_my_damage, {source = self})          # only events published with this source
bus.subscribe(Damaged, shared_effect.on_damage, {source = enemy})  # the same handler once per source
bus.unsubscribe(Damaged, shared_effect.on_damage, enemy)        # removes only that source
bus.publish(Damaged.new(5), self)                               # source is stored in event.source
```

- Order: higher `priority` first (default 0). For equal priorities, handlers of the event's own class run before
  those of its base classes, then in subscription order. Priority applies across the class hierarchy.
- Without priorities, handler order is subscription order, which in a modular game is module start order. When one
  handler must see the result of another (count the points before announcing the wave cleared), say so with a
  priority instead of relying on the order modules happen to start in.
- A handler subscribed with `source` receives only events published with that same object; handlers without a
  source receive every event of the type. This replaces filtering by `get_instance_id()`. A subscription whose
  source object was freed is dropped.
- Unknown option keys and a non-int `priority` are reported and the subscription is refused.
- Sorted handler lists are cached per event class until subscriptions change.

### Many small events

Declare them as inner classes of one named script; they get readable names (`GameEvents.StaminaChanged`) in
messages and in the debugger tab:

```gdscript
class_name GameEvents
extends RefCounted

class StaminaChanged:
	extends TrEvent
	var value: float

class PlayerDied:
	extends TrEvent
```

`bus.subscribe(GameEvents.StaminaChanged, _on_stamina)`.

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
- A handler that uses `await` must be sent with `send_async` (below). `send()` detects it and returns an
  `async_handler` failure instead of a half-finished result.

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

## Asynchronous handlers: send_async

Handlers that wait (file or network I/O, a timer, an animation) use `await` and are sent with `send_async`, which
must itself be awaited:

```gdscript
class_name SaveHighscoreHandler
extends TrRequestHandler

func handles() -> Script:
	return SaveHighscore

func handle(_request: TrRequest) -> TrResult:
	if not _board.is_record():
		return TrResult.success(false)
	var err: Error = await _store.save_best(_board.best)   # the adapter awaits slow storage
	return TrResult.success(true) if err == OK else TrResult.failure(&"save_failed", error_string(err))
```

```gdscript
var result: TrResult = await mediator.send_async(SaveHighscore.new())
```

- `send_async` also works with synchronous handlers.
- Behaviors take part through `process_async(request, next)`, which must `await next.call()`. Its default passes
  straight through, so a behavior that only overrides `process` is skipped by `send_async`.
- GDScript rejects calling a coroutine without `await` when it can see the call (a parse error), but not through a
  base-class reference or a `Callable`. That's why `send()` checks the handler's return value.

## Cost

See [benchmarks](../benchmarks.md). Route player and AI actions through the mediator, not per-frame movement.
