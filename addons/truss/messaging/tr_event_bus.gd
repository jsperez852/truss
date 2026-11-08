class_name TrEventBus
extends RefCounted
## Typed publish/subscribe for [TrEvent] classes.
##
## The event class is the topic: handlers subscribe to a script, receive typed instances, and a typo in the
## event name is a parse error instead of a silent failure. Handlers subscribed to a base event class also
## receive its subclasses. Handlers whose object was freed are dropped automatically.
## [codeblock]
## bus.subscribe(EnemyDied, _on_enemy_died)
## bus.publish(EnemyDied.new(&"slime"))
##
## func _on_enemy_died(event: EnemyDied) -> void:
##     kills += 1
## [/codeblock]
## Prefer local signals between nodes that share a parent. Use the bus for facts that unrelated systems care about.

## Emitted after an event was delivered (used by the editor debugger tab). Costs one signal emit per publish.
signal published(event: TrEvent)

var _handlers: Dictionary[Script, Array] = {}
var _publishing: int = 0


## Subscribes [param handler] (a [Callable] taking one argument) to [param event_type] and its subclasses.
## Subscribing the same handler twice has no effect. Returns [code]false[/code] if the arguments are invalid.
func subscribe(event_type: Script, handler: Callable) -> bool:
	if not _is_event_script(event_type):
		push_error("TrEventBus.subscribe(): %s is not a TrEvent subclass" % TrContracts.describe(event_type))
		return false
	if not handler.is_valid():
		push_error("TrEventBus.subscribe(): invalid handler for %s" % TrContracts.describe(event_type))
		return false
	var list: Array = _handlers.get_or_add(event_type, [])
	if not list.has(handler):
		list.append(handler)
	return true


## Removes [param handler] from [param event_type]. Safe to call during [method publish].
func unsubscribe(event_type: Script, handler: Callable) -> void:
	if _handlers.has(event_type):
		var list: Array = _handlers[event_type]
		list.erase(handler)


## Removes every subscription whose callable is bound to [param target] (for example in [code]_exit_tree()[/code]).
func unsubscribe_all(target: Object) -> void:
	for event_type: Script in _handlers:
		var list: Array = _handlers[event_type]
		for i: int in range(list.size() - 1, -1, -1):
			var handler: Callable = list[i]
			if handler.get_object() == target:
				list.remove_at(i)


## Delivers [param event] to the handlers of its class, then to those of each parent event class.
## Returns how many handlers were called.
func publish(event: TrEvent) -> int:
	if event == null:
		push_error("TrEventBus.publish(): event is null")
		return 0
	_publishing += 1
	var called: int = 0
	var script: Script = event.get_script() as Script
	while script != null:
		if _handlers.has(script):
			var list: Array = _handlers[script]
			for handler: Callable in list.duplicate():
				if not handler.is_valid():
					list.erase(handler)
					continue
				if list.has(handler):
					handler.call(event)
					called += 1
		script = script.get_base_script()
	_publishing -= 1
	published.emit(event)
	return called


## Number of live handlers subscribed directly to [param event_type].
func subscriber_count(event_type: Script) -> int:
	if not _handlers.has(event_type):
		return 0
	var count: int = 0
	for handler: Callable in _handlers[event_type]:
		if handler.is_valid():
			count += 1
	return count


func clear() -> void:
	_handlers.clear()


func _is_event_script(script: Script) -> bool:
	var current: Script = script
	while current != null:
		if current == TrEvent:
			return true
		current = current.get_base_script()
	return false
