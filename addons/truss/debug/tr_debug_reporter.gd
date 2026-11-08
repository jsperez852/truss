class_name TrDebugReporter
extends RefCounted
## Sends Truss runtime information to the editor's "Truss" debugger tab while the game runs from the editor.
##
## The Truss autoload creates it after a successful boot when [method EngineDebugger.is_active] is true.
## It reports the modules and container registrations once, then every published [TrEvent] and every
## [TrRequest] sent through a [TrMediator] registered in the container. Messages use the "truss:" prefix.

const PREFIX: String = "truss"
const LIFETIME_NAMES: PackedStringArray = ["singleton", "scoped", "transient", "instance"]

var _bus: TrEventBus
var _mediator: TrMediator
var _behavior: DebugBehavior


## Times every request and reports it. Added to the mediator's pipeline as its outermost behavior.
class DebugBehavior:
	extends TrBehavior
	var reporter: TrDebugReporter

	func process(request: TrRequest, next: Callable) -> TrResult:
		var started: int = Time.get_ticks_usec()
		var result: TrResult = next.call()
		reporter.send(&"request", TrDebugReporter.request_payload(request, result, Time.get_ticks_usec() - started, false))
		return result

	func process_async(request: TrRequest, next: Callable) -> TrResult:
		var started: int = Time.get_ticks_usec()
		var result: TrResult = await next.call()
		reporter.send(&"request", TrDebugReporter.request_payload(request, result, Time.get_ticks_usec() - started, true))
		return result


## Reports [param bootstrap]'s modules and container, and starts reporting events and requests.
func attach(bootstrap: TrBootstrap) -> void:
	var container: TrServiceContainer = bootstrap.get_container()
	send(&"boot", boot_payload(bootstrap.module_names(), container))
	if container.has(TrEventBus):
		_bus = container.get_service(TrEventBus) as TrEventBus
		_bus.published.connect(_on_published)
	if container.has(TrMediator):
		_mediator = container.get_service(TrMediator) as TrMediator
		_behavior = DebugBehavior.new()
		_behavior.reporter = self
		_mediator.add_behavior(_behavior)


func detach() -> void:
	if _bus != null and _bus.published.is_connected(_on_published):
		_bus.published.disconnect(_on_published)
	if _mediator != null and _behavior != null:
		_mediator.remove_behavior(_behavior)
	if _behavior != null:
		_behavior.reporter = null
	_bus = null
	_mediator = null
	_behavior = null


## Sends a "truss:<message>" debugger message, only when the game runs with the editor's debugger.
func send(message: StringName, data: Array) -> void:
	if EngineDebugger.is_active():
		EngineDebugger.send_message("%s:%s" % [PREFIX, message], data)


## [code][modules: PackedStringArray, services: Array of [contract, lifetime]][/code]
static func boot_payload(module_names: PackedStringArray, container: TrServiceContainer) -> Array:
	var services: Array = []
	for contract: Script in container.registered_contracts():
		var lifetime: int = container.lifetime_of(contract)
		services.append([TrContracts.describe(contract), LIFETIME_NAMES[lifetime] if lifetime >= 0 else "?"])
	return [module_names, services]


## [code][event class, frame][/code]
static func event_payload(event: TrEvent) -> Array:
	return [TrContracts.describe_value(event), Engine.get_process_frames()]


## [code][request class, ok, error, microseconds, async][/code]
static func request_payload(request: TrRequest, result: TrResult, usec: int, is_async: bool) -> Array:
	var ok: bool = result != null and result.ok
	var error: String = String(result.error) if result != null else "null_result"
	return [TrContracts.describe_value(request), ok, error, usec, is_async]


func _on_published(event: TrEvent) -> void:
	send(&"event", event_payload(event))
