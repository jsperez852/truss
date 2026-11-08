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

const SETTING_AUTOMATIC_INJECTION: String = "truss/injection/automatic"

## The application (root) container. Valid after [method boot] succeeded.
var container: TrServiceContainer
## The injector, created by [method boot].
var injector: TrInjector
var _bootstrap: TrBootstrap


## Boots [param modules] (an [Array] of [TrModule]) with a new [TrBootstrap]. On success, starts automatic injection (unless disabled)
## and injects nodes already in the tree. Returns the bootstrap's [TrResult].
func boot(modules: Array, root_container: TrServiceContainer = null) -> TrResult:
	if _bootstrap != null and _bootstrap.is_booted():
		return TrResult.failure(TrBootstrap.ERR_ALREADY_BOOTED, "Truss.boot() was already called")
	_bootstrap = TrBootstrap.new(root_container)
	_bootstrap.add_all(modules)
	var result: TrResult = _bootstrap.boot()
	if result.is_err():
		return result
	container = _bootstrap.get_container()
	injector = TrInjector.new(container)
	if automatic_injection_enabled():
		injector.attach(get_tree())
		injector.inject_tree(get_tree().root)
	return result


## Stops the modules and disposes the container. Called automatically when the game quits.
func shutdown() -> void:
	if injector != null:
		injector.detach()
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_booted():
		shutdown()
