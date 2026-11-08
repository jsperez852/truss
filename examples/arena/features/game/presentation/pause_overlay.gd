extends CanvasLayer
## Esc toggles a pause token. Runs while paused (process_mode ALWAYS).

var _pause: TrPause
var _token: TrPauseToken
@onready var _label: Label = $Label


func _inject(c: TrServiceContainer) -> void:
	_pause = c.get_service(TrPause) as TrPause


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _pause != null and event.is_action_pressed(&"ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if _token != null:
		_token.release()
		_token = null
	else:
		_token = _pause.acquire(&"pause_menu")
	_label.visible = _token != null
