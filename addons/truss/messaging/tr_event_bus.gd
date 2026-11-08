class_name TrEventBus
extends RefCounted
## Typed publish/subscribe for [TrEvent] classes.
##
## The event class is the topic: handlers subscribe to a script, receive typed instances, and a typo in the
## event name is a parse error instead of a silent failure. Handlers subscribed to a base event class also
## receive its subclasses. Handlers whose object was freed are dropped automatically.
## [codeblock]
## bus.subscribe(EnemyDied, _on_enemy_died)
## bus.subscribe(EnemyDied, _count_score, {priority = 10})        # higher priority runs first
## bus.subscribe(Damaged, _on_my_damage, {source = self})         # only events published with this source
## bus.publish(EnemyDied.new(&"slime"))
## bus.publish(Damaged.new(5), self)
##
## func _on_enemy_died(event: EnemyDied) -> void:
##     kills += 1
##
## func _on_player_died() -> void:                               # handlers may skip the event argument
##     lives -= 1
## [/codeblock]
## Handlers bound to a [Node] are skipped while the node is outside the scene tree and dropped when it is freed,
## so nodes don't need to unsubscribe in [code]_exit_tree()[/code].
## Order: higher [code]priority[/code] first (default 0); for equal priorities, handlers of the event's own class
## before handlers of its base classes, then subscription order.
## Prefer local signals between nodes that share a parent. Use the bus for facts that unrelated systems care about.

## Emitted when an event is published, before its handlers run, so nested publishes keep their real order
## (used by the editor debugger tab). Costs one signal emit per publish.
signal published(event: TrEvent)

const OPTION_KEYS: PackedStringArray = ["priority", "source", "outside_tree"]


class Subscription:
	extends RefCounted
	var handler: Callable
	var priority: int = 0
	var sequence: int = 0
	var has_source: bool = false
	var source_ref: WeakRef
	var pass_event: bool = true
	var node_ref: WeakRef
	var active: bool = true

	func is_alive() -> bool:
		return active and handler.is_valid() and (not has_source or source_ref.get_ref() != null)

	func accepts(source: Object) -> bool:
		if has_source and (source == null or source_ref.get_ref() != source):
			return false
		if node_ref == null:
			return true
		var node: Node = node_ref.get_ref() as Node
		return node != null and node.is_inside_tree()

	func same_source(source: Variant) -> bool:
		if not has_source:
			return source == null
		return source != null and source_ref.get_ref() == source

	func deliver(event: TrEvent) -> void:
		if pass_event:
			handler.call(event)
		else:
			handler.call()


var _subscriptions: Dictionary[Script, Array] = {}
var _dispatch_cache: Dictionary[Script, Array] = {}
var _sequence: int = 0


## Subscribes [param handler] to [param event_type] and its subclasses. The handler takes the event as its only
## argument, or no argument at all when it doesn't need it.
## [param options]: [code]priority[/code] (int, default 0, higher runs first), [code]source[/code] (an Object:
## only events published with that same source are delivered) and [code]outside_tree[/code] (bool, default
## [code]false[/code]: handlers bound to a Node are skipped while the node is outside the tree; [code]true[/code]
## delivers anyway). Subscribing the same handler to the same type and source twice has no effect; the same
## handler with different sources (one shared Resource listening to several characters) is several subscriptions.
## Returns [code]false[/code] if the arguments are invalid.
func subscribe(event_type: Script, handler: Callable, options: Dictionary = {}) -> bool:
	if not _is_event_script(event_type):
		push_error("TrEventBus.subscribe(): %s is not a TrEvent subclass" % TrContracts.describe(event_type))
		return false
	if not handler.is_valid():
		push_error("TrEventBus.subscribe(): invalid handler for %s" % TrContracts.describe(event_type))
		return false
	for key: Variant in options:
		if not OPTION_KEYS.has(str(key)):
			push_error("TrEventBus.subscribe(): unknown option %s (valid: %s)" % [str(key), ", ".join(OPTION_KEYS)])
			return false
	var arg_count: int = handler.get_argument_count()
	if arg_count > 1:
		push_error("TrEventBus.subscribe(): handler for %s takes %d arguments (expected the event, or none)" % [TrContracts.describe(event_type), arg_count])
		return false
	var outside_tree: Variant = options.get("outside_tree", false)
	if typeof(outside_tree) != TYPE_BOOL:
		push_error("TrEventBus.subscribe(): outside_tree must be a bool, got %s" % type_string(typeof(outside_tree)))
		return false
	var list: Array = _subscriptions.get_or_add(event_type, [])
	var source_key: Variant = options.get("source", null)
	for existing: Subscription in list:
		if existing.active and existing.handler == handler and existing.same_source(source_key):
			return true
	var sub := Subscription.new()
	sub.handler = handler
	sub.pass_event = arg_count == 1
	var target: Object = handler.get_object()
	var deliver_outside: bool = outside_tree
	if target is Node and not deliver_outside:
		sub.node_ref = weakref(target)
	var priority: Variant = options.get("priority", 0)
	if typeof(priority) != TYPE_INT:
		push_error("TrEventBus.subscribe(): priority must be an int, got %s" % type_string(typeof(priority)))
		return false
	sub.priority = priority
	var source: Variant = options.get("source", null)
	if source != null:
		if typeof(source) != TYPE_OBJECT or not is_instance_valid(source):
			push_error("TrEventBus.subscribe(): source must be a valid Object")
			return false
		var source_object: Object = source
		sub.has_source = true
		sub.source_ref = weakref(source_object)
	_sequence += 1
	sub.sequence = _sequence
	list.append(sub)
	_dispatch_cache.clear()
	return true


## Removes [param handler] from [param event_type]: only its subscription with [param source] when given, every
## subscription of the handler otherwise. Safe to call during [method publish]: a handler removed by an earlier
## handler of the same event isn't called.
func unsubscribe(event_type: Script, handler: Callable, source: Object = null) -> void:
	if not _subscriptions.has(event_type):
		return
	var list: Array = _subscriptions[event_type]
	for i: int in range(list.size() - 1, -1, -1):
		var sub: Subscription = list[i]
		if sub.handler == handler and (source == null or sub.same_source(source)):
			sub.active = false
			list.remove_at(i)
	_dispatch_cache.clear()


## Removes every subscription whose callable is bound to [param target]. Nodes rarely need it: their handlers
## are skipped outside the tree and dropped when they are freed.
func unsubscribe_all(target: Object) -> void:
	for event_type: Script in _subscriptions:
		var list: Array = _subscriptions[event_type]
		for i: int in range(list.size() - 1, -1, -1):
			var sub: Subscription = list[i]
			if sub.handler.get_object() == target:
				sub.active = false
				list.remove_at(i)
	_dispatch_cache.clear()


## Delivers [param event] to every matching handler in priority order. [param source] (optional) is stored in
## [member TrEvent.source] and used to filter handlers subscribed with a [code]source[/code] option.
## Returns how many handlers were called. Handlers subscribed while publishing take effect from the next event.
func publish(event: TrEvent, source: Object = null) -> int:
	if event == null:
		push_error("TrEventBus.publish(): event is null")
		return 0
	if source != null:
		event.source = source
	published.emit(event)
	var called: int = 0
	var has_dead: bool = false
	for sub: Subscription in _dispatch_list(event.get_script() as Script):
		if not sub.is_alive():
			has_dead = true
			continue
		if sub.accepts(event.source):
			sub.deliver(event)
			called += 1
	if has_dead:
		_prune()
	return called


## Number of live handlers subscribed directly to [param event_type].
func subscriber_count(event_type: Script) -> int:
	var count: int = 0
	for sub: Subscription in _subscriptions.get(event_type, []):
		if sub.is_alive():
			count += 1
	return count


func clear() -> void:
	for list: Array in _subscriptions.values():
		for sub: Subscription in list:
			sub.active = false
	_subscriptions.clear()
	_dispatch_cache.clear()


## Handlers for an event class across its hierarchy, sorted once and cached until subscriptions change.
func _dispatch_list(event_type: Script) -> Array:
	if _dispatch_cache.has(event_type):
		return _dispatch_cache[event_type]
	var entries: Array = []  # [priority, depth, sequence, subscription]
	var depth: int = 0
	var script: Script = event_type
	while script != null:
		for sub: Subscription in _subscriptions.get(script, []):
			entries.append([sub.priority, depth, sub.sequence, sub])
		depth += 1
		script = script.get_base_script()
	entries.sort_custom(_before)
	var ordered: Array = []
	for entry: Array in entries:
		ordered.append(entry[3])
	_dispatch_cache[event_type] = ordered
	return ordered


static func _before(a: Array, b: Array) -> bool:
	var pa: int = a[0]
	var pb: int = b[0]
	if pa != pb:
		return pa > pb
	var da: int = a[1]
	var db: int = b[1]
	if da != db:
		return da < db
	var sa: int = a[2]
	var sb: int = b[2]
	return sa < sb


func _prune() -> void:
	for event_type: Script in _subscriptions:
		var list: Array = _subscriptions[event_type]
		for i: int in range(list.size() - 1, -1, -1):
			var sub: Subscription = list[i]
			if not sub.is_alive():
				sub.active = false
				list.remove_at(i)
	_dispatch_cache.clear()


func _is_event_script(script: Script) -> bool:
	var current: Script = script
	while current != null:
		if current == TrEvent:
			return true
		current = current.get_base_script()
	return false
