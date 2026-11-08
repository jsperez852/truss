extends Node
## The "Truss" autoload, added when the Truss plugin is enabled. It owns the application container, the
## bootstrap and the automatic injector.
##
## Boot from your composition root, an autoload listed [b]after[/b] Truss, so the container is ready before
## the main scene loads and its nodes get [code]_inject()[/code] before [code]_ready()[/code]:
## [codeblock]
## # res://app/app.gd (autoload "App", after "Truss")
## extends Node
##
## func _ready() -> void:
##     var result: TrResult = Truss.boot([SaveModule.new(), InventoryModule.new()])
##     if result.is_err():
##         push_error(result.message)
##         get_tree().quit(1)
## [/codeblock]
## Project setting [code]truss/injection/automatic[/code] (default [code]true[/code]) controls whether the
## injector listens to the scene tree. When it's off, call [code]Truss.injector.inject(node)[/code] yourself.
## [br][br]
## [member pause] works without booting. Lifecycle notifications (focus, app pause/resume, close request)
## become [TrAppEvents] events: emitted as [signal app_event] and published on the container's [TrEventBus].
## Setting [code]truss/lifecycle/pause_on_focus_loss[/code] (default [code]false[/code], recommended on mobile)
## holds a pause token while the app is unfocused or paused by the OS.

## Emitted for every application lifecycle event, booted or not.
signal app_event(event: TrAppEvents.AppEvent)

const SETTING_AUTOMATIC_INJECTION: String = "truss/injection/automatic"
const SETTING_PAUSE_ON_FOCUS_LOSS: String = "truss/lifecycle/pause_on_focus_loss"

## The application (root) container. Valid after [method boot] succeeded.
var container: TrServiceContainer
## The injector, created by [method boot].
var injector: TrInjector
## Pause tokens and hit stop (see [TrPause]).
var pause: TrPause
var _focus_token: TrPauseToken
var _app_unfocused: bool = false
var _app_paused: bool = false
var _bootstrap: TrBootstrap
var _reporter: TrDebugReporter


## Boots [param modules] (an [Array] of [TrModule]) with a new [TrBootstrap]. [member pause] is registered in the
## container as [TrPause]. On success, starts automatic injection (unless disabled) and injects nodes already in
## the tree. Returns the bootstrap's [TrResult].
func boot(modules: Array, root_container: TrServiceContainer = null) -> TrResult:
	if _bootstrap != null and _bootstrap.is_booted():
		return TrResult.failure(TrBootstrap.ERR_ALREADY_BOOTED, "Truss.boot() was already called")
	# Truss.pause is registered as a TrPause instance so nodes and services can receive it through injection.
	var root: TrServiceContainer = root_container if root_container != null else TrServiceContainer.new()
	if pause == null:
		pause = TrPause.new(get_tree())
	if not root.has(TrPause):
		root.instance(TrPause, pause)
	_bootstrap = TrBootstrap.new(root)
	_bootstrap.add_all(modules)
	var result: TrResult = _bootstrap.boot()
	if result.is_err():
		return result
	container = _bootstrap.get_container()
	injector = TrInjector.new(container)
	if automatic_injection_enabled():
		injector.attach(get_tree())
		injector.inject_tree(get_tree().root)
	if EngineDebugger.is_active():
		_reporter = TrDebugReporter.new()
		_reporter.attach(_bootstrap, pause)
	return result


## Stops the modules and disposes the container. Called automatically when the game quits.
func shutdown() -> void:
	if injector != null:
		injector.detach()
	if _reporter != null:
		_reporter.detach()
		_reporter = null
	if _bootstrap != null and _bootstrap.is_booted():
		_bootstrap.shutdown()
	_bootstrap = null
	container = null
	injector = null


func is_booted() -> bool:
	return _bootstrap != null and _bootstrap.is_booted()


## The value of [code]truss/injection/automatic[/code] (default [code]true[/code]).
func automatic_injection_enabled() -> bool:
	var enabled: bool = ProjectSettings.get_setting(SETTING_AUTOMATIC_INJECTION, true)
	return enabled


func _enter_tree() -> void:
	if pause == null:
		pause = TrPause.new(get_tree())


## The value of [code]truss/lifecycle/pause_on_focus_loss[/code] (default [code]false[/code]).
func pause_on_focus_loss_enabled() -> bool:
	var enabled: bool = ProjectSettings.get_setting(SETTING_PAUSE_ON_FOCUS_LOSS, false)
	return enabled


## Turns a lifecycle notification into a [TrAppEvents] event. Called by [method _notification]; public so
## tests and tools can simulate the OS.
func handle_lifecycle(what: int) -> TrAppEvents.AppEvent:
	var event: TrAppEvents.AppEvent = TrAppEvents.from_notification(what)
	if event == null:
		return null
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_app_unfocused = true
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_app_unfocused = false
		NOTIFICATION_APPLICATION_PAUSED:
			_app_paused = true
		NOTIFICATION_APPLICATION_RESUMED:
			_app_paused = false
	_update_focus_pause()
	app_event.emit(event)
	if container != null and not container.is_disposed() and container.has(TrEventBus):
		(container.get_service(TrEventBus) as TrEventBus).publish(event)
	return event


func _update_focus_pause() -> void:
	var away: bool = _app_unfocused or _app_paused
	if away and pause_on_focus_loss_enabled() and _focus_token == null and pause != null:
		_focus_token = pause.acquire(&"focus_lost")
	elif not away and _focus_token != null:
		_focus_token.release()
		_focus_token = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_booted():
			shutdown()
		return
	handle_lifecycle(what)
