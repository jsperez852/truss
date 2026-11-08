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
## A missing handler is a programming error: it is reported and returned as a failure.
func send(request: TrRequest) -> TrResult:
	if request == null:
		push_error("TrMediator.send(): request is null")
		return TrResult.failure(ERR_INVALID_REQUEST, "request is null")
	var request_type: Script = request.get_script() as Script
	if not _handlers.has(request_type):
		var text: String = "no handler registered for %s" % TrContracts.describe(request_type)
		push_error("TrMediator.send(): " + text)
		return TrResult.failure(ERR_NO_HANDLER, text)
	return _run(request, _handlers[request_type], 0)


func _run(request: TrRequest, handler: TrRequestHandler, index: int) -> TrResult:
	if index >= _behaviors.size():
		return _checked(handler.handle(request), TrContracts.describe_value(handler))
	var behavior: TrBehavior = _behaviors[index]
	var next: Callable = _run.bind(request, handler, index + 1)
	return _checked(behavior.process(request, next), TrContracts.describe_value(behavior))


func _checked(result: TrResult, source: String) -> TrResult:
	if result == null:
		push_error("TrMediator: %s returned null instead of a TrResult" % source)
		return TrResult.failure(ERR_INVALID_RESULT, "%s returned null" % source)
	return result


func _is_request_script(script: Script) -> bool:
	var current: Script = script
	while current != null:
		if current == TrRequest:
			return true
		current = current.get_base_script()
	return false
