extends Label
## Presentation: receives the mediator and the event bus through _inject() before _ready().

var _mediator: TrMediator
var _bus: TrEventBus


func _inject(c: TrServiceContainer) -> void:
	_mediator = c.get_service(TrMediator) as TrMediator
	_bus = c.get_service(TrEventBus) as TrEventBus


func _ready() -> void:
	if _mediator == null:
		return  # boot failed: App already asked the game to quit
	_bus.subscribe(PointsChanged, _on_points_changed)
	for amount: int in [5, 10, -1]:
		var result: TrResult = _mediator.send(AddPoints.new(amount))
		if result.is_err():
			print("rejected %d: %s" % [amount, result.message])
	print("final label: ", text)
	get_tree().quit(0)


func _exit_tree() -> void:
	if _bus != null:
		_bus.unsubscribe_all(self)


func _on_points_changed(event: PointsChanged) -> void:
	text = "Score: %d" % event.total
	print("label updated -> ", text)
