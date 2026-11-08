class_name TrBootstrap
extends RefCounted
## The composition root: orders [TrModule]s by their dependencies, registers them, validates the container and
## starts them. Fails before starting anything when a dependency is missing, modules form a cycle, or the
## container is invalid.
## [codeblock]
## var boot := TrBootstrap.new()
## boot.add(SaveModule.new()).add(InventoryModule.new())
## var result: TrResult = boot.boot()
## if result.is_err():
##     push_error(result.message)
##     get_tree().quit(1)
## [/codeblock]

const ERR_ALREADY_BOOTED: StringName = &"already_booted"
const ERR_DUPLICATE_MODULE: StringName = &"duplicate_module"
const ERR_MISSING_DEPENDENCY: StringName = &"missing_dependency"
const ERR_MODULE_CYCLE: StringName = &"module_cycle"
const ERR_INVALID_CONTAINER: StringName = &"invalid_container"

var _modules: Dictionary[Script, TrModule] = {}
var _added_order: Array[Script] = []
var _started: Array[TrModule] = []
var _container: TrServiceContainer
var _booted: bool = false
var _duplicates: PackedStringArray = []


## Uses [param container] as the root container, or creates one.
func _init(container: TrServiceContainer = null) -> void:
	_container = container if container != null else TrServiceContainer.new()


## Adds a module. Returns the bootstrap so calls can be chained.
## Adding two modules of the same class is reported by [method boot].
func add(module: TrModule) -> TrBootstrap:
	if module == null:
		push_error("TrBootstrap.add(): module is null")
		return self
	var key: Script = module.get_script() as Script
	if _modules.has(key):
		_duplicates.append(module.module_name())
		return self
	_modules[key] = module
	_added_order.append(key)
	return self


## Adds several modules in order. Accepts any [Array] (typed or not); non-module items are reported.
func add_all(modules: Array) -> TrBootstrap:
	for item: Variant in modules:
		if item is TrModule:
			add(item as TrModule)
		else:
			push_error("TrBootstrap.add_all(): %s is not a TrModule" % TrContracts.describe_value(item))
	return self


## Orders, registers, validates and starts the modules. Returns a success holding the container, or a failure
## (nothing is started) whose message explains every problem found.
func boot() -> TrResult:
	if _booted:
		return TrResult.failure(ERR_ALREADY_BOOTED, "TrBootstrap.boot() was already called")
	if not _duplicates.is_empty():
		return TrResult.failure(ERR_DUPLICATE_MODULE, "module added twice: %s" % ", ".join(_duplicates))
	var ordered: TrResult = order()
	if ordered.is_err():
		return ordered
	var modules: Array[TrModule] = []
	modules.assign(ordered.value as Array)
	for module: TrModule in modules:
		module.register(_container)
	var validation: TrResult = _container.validate()
	if validation.is_err():
		return TrResult.failure(ERR_INVALID_CONTAINER, "container validation failed:\n%s" % validation.message)
	_booted = true
	for module: TrModule in modules:
		module.start(_container)
		_started.append(module)
	return TrResult.success(_container)


## The modules in dependency order (dependencies first, otherwise in the order they were added), as a
## [TrResult] holding an [code]Array[TrModule][/code]. Doesn't register anything.
func order() -> TrResult:
	var problems := PackedStringArray()
	for key: Script in _added_order:
		for dependency: Script in _modules[key].dependencies():
			if not _modules.has(dependency):
				problems.append("%s depends on %s, which was not added" % [_name_of(key), _name_of(dependency)])
	if not problems.is_empty():
		return TrResult.failure(ERR_MISSING_DEPENDENCY, "\n".join(problems))
	var result: Array[TrModule] = []
	var state: Dictionary[Script, int] = {}  # 1 = visiting, 2 = done
	var path: Array[Script] = []
	for key: Script in _added_order:
		var cycle: PackedStringArray = _visit(key, state, path, result)
		if not cycle.is_empty():
			return TrResult.failure(ERR_MODULE_CYCLE, "module dependency cycle: %s" % " -> ".join(cycle))
	return TrResult.success(result)


## Calls [method TrModule.stop] on started modules in reverse order, then disposes the container.
func shutdown() -> void:
	for i: int in range(_started.size() - 1, -1, -1):
		_started[i].stop(_container)
	_started.clear()
	_container.dispose()


## The root container (also before [method boot], for tests that want to pre-register overrides).
func get_container() -> TrServiceContainer:
	return _container


func is_booted() -> bool:
	return _booted


## Names of the added modules, in the order they were added.
func module_names() -> PackedStringArray:
	var names := PackedStringArray()
	for key: Script in _added_order:
		names.append(_name_of(key))
	return names


func _name_of(key: Script) -> String:
	return _modules[key].module_name() if _modules.has(key) else TrContracts.describe(key)



func _visit(key: Script, state: Dictionary[Script, int], path: Array[Script], out: Array[TrModule]) -> PackedStringArray:
	var current: int = state.get(key, 0)
	if current == 2:
		return PackedStringArray()
	if current == 1:
		var cycle := PackedStringArray()
		for item: Script in path.slice(path.find(key)):
			cycle.append(_name_of(item))
		cycle.append(_name_of(key))
		return cycle
	state[key] = 1
	path.append(key)
	for dependency: Script in _modules[key].dependencies():
		var cycle: PackedStringArray = _visit(dependency, state, path, out)
		if not cycle.is_empty():
			return cycle
	path.pop_back()
	state[key] = 2
	out.append(_modules[key])
	return PackedStringArray()
