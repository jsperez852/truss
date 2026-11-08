extends SceneTree
## Micro-benchmarks: Truss messaging and DI against native Godot signals and direct calls.
## Usage: godot --headless --path . -s res://tools/bench.gd [-- --iterations=200000]
## Numbers come from the build you run (editor builds are debug builds), so compare rows, not absolutes.

const HANDLERS: int = 3


class Counter:
	extends RefCounted
	var n: int = 0
	func on_value(_v: int) -> void:
		n += 1
	func on_event(_e: TrEvent) -> void:
		n += 1


class Emitter:
	extends RefCounted
	signal value_changed(v: int)


class BenchEvent:
	extends TrEvent
	var v: int


class BenchRequest:
	extends TrRequest
	var v: int


class BenchHandler:
	extends TrRequestHandler
	func handles() -> Script:
		return BenchRequest
	func handle(request: TrRequest) -> TrResult:
		return TrResult.success((request as BenchRequest).v + 1)


class PassThrough:
	extends TrBehavior
	func process(_request: TrRequest, next: Callable) -> TrResult:
		return next.call()


class Service:
	extends RefCounted


var _iterations: int = 200000


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--iterations="):
			_iterations = int(arg.trim_prefix("--iterations="))
	print("Truss benchmarks — Godot %s, %d iterations, %d handlers where relevant" % [Engine.get_version_info()["string"], _iterations, HANDLERS])
	print("| Operation | µs per call |")
	print("|---|---|")
	_bench_signal()
	_bench_bus()
	_bench_direct_call()
	_bench_mediator(0)
	_bench_mediator(2)
	_bench_container()
	quit()


func _row(label: String, start_usec: int) -> void:
	var per_call: float = float(Time.get_ticks_usec() - start_usec) / float(_iterations)
	print("| %s | %.3f |" % [label, per_call])


func _bench_signal() -> void:
	var emitter := Emitter.new()
	var counters: Array[Counter] = []
	for i: int in HANDLERS:
		var c := Counter.new()
		counters.append(c)
		emitter.value_changed.connect(c.on_value)
	var start: int = Time.get_ticks_usec()
	for i: int in _iterations:
		emitter.value_changed.emit(i)
	_row("native signal emit (%d handlers)" % HANDLERS, start)


func _bench_bus() -> void:
	var bus := TrEventBus.new()
	var counters: Array[Counter] = []
	for i: int in HANDLERS:
		var c := Counter.new()
		counters.append(c)
		bus.subscribe(BenchEvent, c.on_event)
	var event := BenchEvent.new()
	var start: int = Time.get_ticks_usec()
	for i: int in _iterations:
		bus.publish(event)
	_row("TrEventBus.publish (%d handlers)" % HANDLERS, start)
	start = Time.get_ticks_usec()
	for i: int in _iterations:
		bus.publish(BenchEvent.new())
	_row("TrEventBus.publish with a new event each time", start)


func _bench_direct_call() -> void:
	var handler := BenchHandler.new()
	var request := BenchRequest.new()
	var start: int = Time.get_ticks_usec()
	for i: int in _iterations:
		handler.handle(request)
	_row("direct handler.handle() call", start)


func _bench_mediator(behaviors: int) -> void:
	var mediator := TrMediator.new()
	mediator.register(BenchHandler.new())
	for i: int in behaviors:
		mediator.add_behavior(PassThrough.new())
	var request := BenchRequest.new()
	var start: int = Time.get_ticks_usec()
	for i: int in _iterations:
		mediator.send(request)
	_row("TrMediator.send (%d behaviors)" % behaviors, start)


func _bench_container() -> void:
	var c := TrServiceContainer.new()
	c.singleton(Service, func() -> Service: return Service.new())
	c.transient(Counter, func() -> Counter: return Counter.new())
	c.get_service(Service)
	var start: int = Time.get_ticks_usec()
	for i: int in _iterations:
		c.get_service(Service)
	_row("TrServiceContainer.get_service (singleton)", start)
	start = Time.get_ticks_usec()
	for i: int in _iterations:
		c.get_service(Counter)
	_row("TrServiceContainer.get_service (transient)", start)
	start = Time.get_ticks_usec()
	for i: int in _iterations:
		Counter.new()
	_row("plain Counter.new()", start)
