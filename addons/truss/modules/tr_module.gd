@abstract class_name TrModule
extends RefCounted
## A feature's entry point: declares which modules it needs and registers its services.
##
## [codeblock]
## class_name InventoryModule
## extends TrModule
##
## func dependencies() -> Array[Script]:
##     return [SaveModule]
##
## func register(c: TrServiceContainer) -> void:
##     c.singleton(Inventory, func() -> Inventory: return Inventory.new(20))
##
## func start(c: TrServiceContainer) -> void:
##     (c.get_service(Inventory) as Inventory).restore()
## [/codeblock]
## [TrBootstrap] calls [method register] on every module in dependency order, validates the container, then
## calls [method start] in the same order. [method stop] runs in reverse order on shutdown.


## The name used in boot messages. Defaults to the [code]class_name[/code]; override it in inner classes,
## which have no name Godot can report.
func module_name() -> String:
	return TrContracts.describe(get_script() as Script)


## Modules (their scripts) that must be registered before this one.
func dependencies() -> Array[Script]:
	return []


## Registers this feature's services. Don't resolve services here: other modules may not have registered yet.
@abstract func register(c: TrServiceContainer) -> void


## Runs after every module registered and the container validated. Resolve services and start work here.
func start(_c: TrServiceContainer) -> void:
	pass


## Runs on shutdown, in reverse start order, before the container is disposed.
func stop(_c: TrServiceContainer) -> void:
	pass
