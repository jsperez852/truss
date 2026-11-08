class_name TrServiceContainer
extends RefCounted
## Dependency injection container. Keys are contract scripts (usually [code]@abstract[/code] ports).
##
## [codeblock]
## var c := TrServiceContainer.new()
## c.singleton(InventoryStore, func() -> InventoryStore: return ConfigInventoryStore.new("user://inv.cfg"))
## c.transient(AddItem, func(s: TrServiceContainer) -> AddItem:
##     return AddItem.new(s.get_service(Inventory) as Inventory, s.get_service(InventoryStore) as InventoryStore))
## var validation: TrResult = c.validate()   # fail fast at startup
## var add_item := c.get_service(AddItem) as AddItem
## [/codeblock]
##
## Factories take no argument or one: the [TrServiceContainer] that resolves the service. Use that argument
## instead of capturing the container in the lambda: a factory that captures its own container creates a
## reference cycle, and the container is never freed. Every resolved object is checked with
## [method @GlobalScope.is_instance_of] against its contract.
## [br][br]
## Lifetimes:
## [br]- [b]singleton[/b]: one instance in the container where it was registered, created on first use.
## [br]- [b]scoped[/b]: one instance per scope that resolves it (see [method create_scope]).
## [br]- [b]transient[/b]: a new instance every time.
## [br]- [b]instance[/b]: an object you created yourself.

enum Lifetime { SINGLETON, SCOPED, TRANSIENT, INSTANCE }

const ERR_NOT_REGISTERED: StringName = &"not_registered"
const ERR_CYCLE: StringName = &"dependency_cycle"
const ERR_CONTRACT: StringName = &"contract_mismatch"
const ERR_FACTORY: StringName = &"factory_failed"
const ERR_DISPOSED: StringName = &"container_disposed"


class Registration:
	extends RefCounted
	var contract: Script
	var lifetime: Lifetime
	var factory: Callable
	var instance: Object

	func _init(p_contract: Script, p_lifetime: Lifetime, p_factory: Callable) -> void:
		contract = p_contract
		lifetime = p_lifetime
		factory = p_factory


var _parent: TrServiceContainer
var _registrations: Dictionary[Script, Registration] = {}
var _scoped_instances: Dictionary[Script, Object] = {}
var _owned: Array[Object] = []
var _children: Array[WeakRef] = []
var _disposed: bool = false
# Resolution state shared by a whole container tree (kept in the root).
var _resolving: Array[Script] = []
var _quiet_depth: int = 0
var _collected_errors: PackedStringArray = []


## Registers a lazily created singleton. Returns the container so calls can be chained.
func singleton(contract: Script, factory: Callable) -> TrServiceContainer:
	return _register(contract, Lifetime.SINGLETON, factory, null)


## Registers a service created once per scope that resolves it.
func scoped(contract: Script, factory: Callable) -> TrServiceContainer:
	return _register(contract, Lifetime.SCOPED, factory, null)


## Registers a service created on every resolution.
func transient(contract: Script, factory: Callable) -> TrServiceContainer:
	return _register(contract, Lifetime.TRANSIENT, factory, null)


## Registers an existing object. It must already implement [param contract].
func instance(contract: Script, object: Object) -> TrServiceContainer:
	if not TrContracts.require(object, contract, "TrServiceContainer.instance()"):
		return self
	return _register(contract, Lifetime.INSTANCE, Callable(), object)


## [code]true[/code] when [param contract] is registered here or in a parent scope.
func has(contract: Script) -> bool:
	return _find(contract) != null


## Resolves [param contract]. Reports an error and returns [code]null[/code] when it can't.
func get_service(contract: Script) -> Object:
	# Fast path: already created singletons and registered instances need no TrResult.
	if not _disposed:
		var registration: Registration = _find(contract)
		if registration != null and registration.instance != null and registration.lifetime != Lifetime.SCOPED:
			return registration.instance
	var result: TrResult = resolve(contract)
	if result.is_err():
		_report(result)
		return null
	return result.value as Object


## Resolves [param contract] without reporting errors: returns a [TrResult] with the object or the reason.
func resolve(contract: Script) -> TrResult:
	if _disposed:
		return TrResult.failure(ERR_DISPOSED, "this scope was disposed")
	var owner: TrServiceContainer = _find_owner(contract)
	if owner == null:
		return TrResult.failure(ERR_NOT_REGISTERED, "%s is not registered" % TrContracts.describe(contract))
	var registration: Registration = owner._registrations[contract]
	match registration.lifetime:
		Lifetime.INSTANCE:
			return TrResult.success(registration.instance)
		Lifetime.SINGLETON:
			if registration.instance == null:
				var made: TrResult = _create(registration, owner)
				if made.is_err():
					return made
				registration.instance = made.value as Object
				owner._own(registration.instance)
			return TrResult.success(registration.instance)
		Lifetime.SCOPED:
			if _scoped_instances.has(contract):
				return TrResult.success(_scoped_instances[contract])
			var made: TrResult = _create(registration, self)
			if made.is_ok():
				_scoped_instances[contract] = made.value as Object
				_own(made.value as Object)
			return made
		_:
			return _create(registration, self)


## Creates a child scope. It sees every registration of this container, can override them, and keeps its
## own scoped instances. Call [method dispose] on it when the scope ends (for example on scene change).
func create_scope() -> TrServiceContainer:
	var child := TrServiceContainer.new()
	child._parent = self
	_children.append(weakref(child))
	return child


## Resolves every registration once to find missing dependencies, cycles and contract mismatches at startup.
## Singletons stay created. Scoped and transient services are created in a temporary scope that is disposed.
## Returns a success, or a failure whose message lists every problem found.
func validate() -> TrResult:
	var root: TrServiceContainer = _root()
	root._quiet_depth += 1
	root._collected_errors.clear()
	var probe: TrServiceContainer = create_scope()
	for contract: Script in _all_contracts():
		var r: TrResult = probe.resolve(contract)
		if r.is_err():
			root._collected_errors.append(r.message)
	probe.dispose()
	root._quiet_depth -= 1
	var problems := PackedStringArray()
	for problem: String in root._collected_errors:
		if not problems.has(problem):
			problems.append(problem)
	root._collected_errors.clear()
	if problems.is_empty():
		return TrResult.success()
	return TrResult.failure(&"invalid_container", "\n".join(problems))


## Contracts registered in this container and its parents, without duplicates.
func registered_contracts() -> Array[Script]:
	return _all_contracts()


## The lifetime of [param contract] as registered (searching parents), or [code]-1[/code] if not registered.
func lifetime_of(contract: Script) -> int:
	var registration: Registration = _find(contract)
	return registration.lifetime if registration != null else -1


## Ends this scope: disposes child scopes, then releases the instances this container created.
## Objects with a [code]dispose()[/code] method get it called; Nodes outside the scene tree are freed.
## Objects registered with [method instance] are never touched.
func dispose() -> void:
	if _disposed:
		return
	for ref: WeakRef in _children:
		var child: TrServiceContainer = ref.get_ref() as TrServiceContainer
		if child != null:
			child.dispose()
	_children.clear()
	for i: int in range(_owned.size() - 1, -1, -1):
		var object: Object = _owned[i]
		if not is_instance_valid(object):
			continue
		if object.has_method(&"dispose"):
			object.call(&"dispose")
		if object is Node and not (object as Node).is_inside_tree():
			(object as Node).free()
	_owned.clear()
	_scoped_instances.clear()
	for registration: Registration in _registrations.values():
		if registration.lifetime == Lifetime.SINGLETON:
			registration.instance = null
	_disposed = true


func is_disposed() -> bool:
	return _disposed


func _register(contract: Script, lifetime: Lifetime, factory: Callable, object: Object) -> TrServiceContainer:
	if contract == null:
		push_error("TrServiceContainer: cannot register a null contract")
		return self
	if _disposed:
		push_error("TrServiceContainer: cannot register %s in a disposed scope" % TrContracts.describe(contract))
		return self
	if lifetime != Lifetime.INSTANCE and not factory.is_valid():
		push_error("TrServiceContainer: invalid factory for %s" % TrContracts.describe(contract))
		return self
	if _registrations.has(contract):
		push_warning("TrServiceContainer: %s was already registered in this scope; replacing it" % TrContracts.describe(contract))
	var registration := Registration.new(contract, lifetime, factory)
	registration.instance = object
	_registrations[contract] = registration
	return self


func _find(contract: Script) -> Registration:
	var owner: TrServiceContainer = _find_owner(contract)
	return owner._registrations[contract] if owner != null else null


## The nearest scope (this one or a parent) that registered [param contract].
func _find_owner(contract: Script) -> TrServiceContainer:
	var scope: TrServiceContainer = self
	while scope != null:
		if scope._registrations.has(contract):
			return scope
		scope = scope._parent
	return null


func _create(registration: Registration, scope: TrServiceContainer) -> TrResult:
	var root: TrServiceContainer = _root()
	var contract: Script = registration.contract
	if root._resolving.has(contract):
		var chain := PackedStringArray()
		for item: Script in root._resolving.slice(root._resolving.find(contract)):
			chain.append(TrContracts.describe(item))
		chain.append(TrContracts.describe(contract))
		return TrResult.failure(ERR_CYCLE, "dependency cycle: %s" % " -> ".join(chain))
	root._resolving.append(contract)
	var argc: int = registration.factory.get_argument_count()
	var produced: Variant = registration.factory.call(scope) if argc >= 1 else registration.factory.call()
	root._resolving.pop_back()
	if not TrContracts.implements(produced, contract):
		var code: StringName = ERR_FACTORY if produced == null else ERR_CONTRACT
		return TrResult.failure(code, "%s: factory returned %s" % [TrContracts.describe(contract), TrContracts.describe_value(produced)])
	return TrResult.success(produced)


func _own(object: Object) -> void:
	if object != null and not _owned.has(object):
		_owned.append(object)


func _report(result: TrResult) -> void:
	var root: TrServiceContainer = _root()
	if root._quiet_depth > 0:
		root._collected_errors.append(result.message)
	else:
		push_error("TrServiceContainer: %s" % result.message)


func _root() -> TrServiceContainer:
	var scope: TrServiceContainer = self
	while scope._parent != null:
		scope = scope._parent
	return scope


func _all_contracts() -> Array[Script]:
	var out: Array[Script] = []
	var scope: TrServiceContainer = self
	while scope != null:
		for contract: Script in scope._registrations:
			if not out.has(contract):
				out.append(contract)
		scope = scope._parent
	return out
