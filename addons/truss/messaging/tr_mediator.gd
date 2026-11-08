class_name TrMediator
extends RefCounted
## Sends each [TrRequest] to the one [TrRequestHandler] registered for its exact class, through the
## [TrBehavior] pipeline.
##
## Use it for player and AI actions (commands) and for reads other features need (queries). Don't route
## per-frame code through it.
## [codeblock]
## var mediator := TrMediator.new()
## mediator.register(AddItemHandler.new(inventory))
## mediator.add_behavior(LogRequests.new())
## var result: TrResult = mediator.send(AddItemRequest.create(potion, 1))
## [/codeblock]

const ERR_NO_HANDLER: StringName = &"no_handler"
const ERR_INVALID_REQUEST: StringName = &"invalid_request"
const ERR_INVALID_RESULT: StringName = &"invalid_result"
const ERR_ASYNC_HANDLER: StringName = &"async_handler"

var _handlers: Dictionary[Script, TrRequestHandler] = {}
var _behaviors: Array[TrBehavior] = []


## Registers [param handler] for the class returned by its [method TrRequestHandler.handles].
## Returns [code]false[/code] (and reports an error) if that class already has a handler or isn't a [TrRequest].
func register(handler: TrRequestHandler) -> bool:
	if handler == null:
		push_error("TrMediator.register(): handler is null")
		return false
	var request_type: Script = handler.handles()
	if not _is_request_script(request_type):
		push_error("TrMediator.register(): %s handles %s, which is not a TrRequest subclass" % [TrContracts.describe_value(handler), TrContracts.describe(request_type)])
		return false
	if _handlers.has(request_type):
		push_error("TrMediator.register(): %s already has a handler (%s)" % [TrContracts.describe(request_type), TrContracts.describe_value(_handlers[request_type])])
		return false
	_handlers[request_type] = handler
	return true


## Removes the handler for [param request_type].
func unregister(request_type: Script) -> void:
	_handlers.erase(request_type)


func has_handler(request_type: Script) -> bool:
	return _handlers.has(request_type)


## Adds a behavior to the pipeline. The first behavior added is the outermost one.
func add_behavior(behavior: TrBehavior) -> void:
	if behavior != null and not _behaviors.has(behavior):
		_behaviors.append(behavior)


func remove_behavior(behavior: TrBehavior) -> void:
	_behaviors.erase(behavior)


## Sends [param request] through the pipeline to its handler and returns the outcome.
## A missing handler is a programming error: it is reported and returned as a failure. A handler that uses
## [code]await[/code] is reported too ([code]async_handler[/code]): send those requests with [method send_async].
func send(request: TrRequest) -> TrResult:
	var handler: TrRequestHandler = _handler_for(request, "send")
	if handler == null:
		return _missing(request)
	return _run(request, handler, 0)


## Like [method send], for handlers and behaviors that [code]await[/code]. Must itself be awaited:
## [code]var result: TrResult = await mediator.send_async(SaveGame.new(slot))[/code].
## Behaviors take part through [method TrBehavior.process_async]. Synchronous handlers work too.
func send_async(request: TrRequest) -> TrResult:
	var handler: TrRequestHandler = _handler_for(request, "send_async")
	if handler == null:
		return _missing(request)
	var result: TrResult = await _run_async(request, handler, 0)
	return result


func _handler_for(request: TrRequest, method: String) -> TrRequestHandler:
	if request == null:
		push_error("TrMediator.%s(): request is null" % method)
		return null
	var request_type: Script = request.get_script() as Script
	if not _handlers.has(request_type):
		push_error("TrMediator.%s(): no handler registered for %s" % [method, TrContracts.describe(request_type)])
		return null
	return _handlers[request_type]


func _missing(request: TrRequest) -> TrResult:
	if request == null:
		return TrResult.failure(ERR_INVALID_REQUEST, "request is null")
	return TrResult.failure(ERR_NO_HANDLER, "no handler registered for %s" % TrContracts.describe(request.get_script() as Script))


func _run(request: TrRequest, handler: TrRequestHandler, index: int) -> TrResult:
	if index >= _behaviors.size():
		# Called through a Variant: a handler that awaits returns a GDScriptFunctionState here.
		var handler_object: Object = handler
		return _checked(handler_object.call(&"handle", request), TrContracts.describe_value(handler))
	var behavior: TrBehavior = _behaviors[index]
	var next: Callable = _run.bind(request, handler, index + 1)
	var behavior_object: Object = behavior
	return _checked(behavior_object.call(&"process", request, next), TrContracts.describe_value(behavior))


func _run_async(request: TrRequest, handler: TrRequestHandler, index: int) -> TrResult:
	if index >= _behaviors.size():
		var produced: Variant = await handler.handle(request)
		return _checked(produced, TrContracts.describe_value(handler))
	var behavior: TrBehavior = _behaviors[index]
	var next: Callable = _run_async.bind(request, handler, index + 1)
	var result: Variant = await behavior.process_async(request, next)
	return _checked(result, TrContracts.describe_value(behavior))


func _checked(produced: Variant, source: String) -> TrResult:
	if produced is TrResult:
		return produced as TrResult
	if produced == null:
		push_error("TrMediator: %s returned null instead of a TrResult" % source)
		return TrResult.failure(ERR_INVALID_RESULT, "%s returned null" % source)
	if produced is Object and (produced as Object).get_class() == "GDScriptFunctionState":
		push_error("TrMediator: %s uses await; send this request with send_async()" % source)
		return TrResult.failure(ERR_ASYNC_HANDLER, "%s is asynchronous; use send_async()" % source)
	push_error("TrMediator: %s returned %s instead of a TrResult" % [source, TrContracts.describe_value(produced)])
	return TrResult.failure(ERR_INVALID_RESULT, "%s did not return a TrResult" % source)


func _is_request_script(script: Script) -> bool:
	var current: Script = script
	while current != null:
		if current == TrRequest:
			return true
		current = current.get_base_script()
	return false
