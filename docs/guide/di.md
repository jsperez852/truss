# di: TrServiceContainer

A dependency injection container keyed by contract scripts. It is a plain `RefCounted`: create it in your
composition root (an autoload or the main scene) and pass it, or the services it builds, to the rest of the game.

```gdscript
var c := TrServiceContainer.new()
c.singleton(InventoryStore, func() -> InventoryStore: return ConfigInventoryStore.new("user://inv.cfg"))
c.singleton(Inventory, func() -> Inventory: return Inventory.new(20))
c.transient(AddItem, func(s: TrServiceContainer) -> AddItem:
	return AddItem.new(s.get_service(Inventory) as Inventory, s.get_service(InventoryStore) as InventoryStore))

var check: TrResult = c.validate()
assert(check.ok, check.message)

var add_item := c.get_service(AddItem) as AddItem
```

## Registrations

| Method | Lifetime |
|---|---|
| `singleton(contract, factory)` | One instance in the container where it was registered, created on first use |
| `scoped(contract, factory)` | One instance per scope that resolves it |
| `transient(contract, factory)` | A new instance on every resolution |
| `instance(contract, object)` | An object you created; it must already implement the contract |

Registering the same contract twice in one scope replaces it and prints a warning. Methods return the container,
so registrations can be chained.

**Factories** take no argument or one, the container that resolves the service. Use that argument instead of
capturing the container in the lambda: a factory that captures its own container creates a reference cycle
(container → registration → lambda → container) and the container is never freed.

Every object a factory returns is checked against its contract with `is_instance_of`. A wrong type or `null`
is a resolution failure, not a silent bug.

## Resolving

| Method | On failure |
|---|---|
| `get_service(contract) -> Object` | Reports the error and returns `null`. Cast the result: `as InventoryStore` |
| `resolve(contract) -> TrResult` | Returns a failure with `error` = `not_registered`, `dependency_cycle`, `contract_mismatch`, `factory_failed` or `container_disposed` |
| `has(contract)`, `lifetime_of(contract)`, `registered_contracts()` | Inspection |

Cycles are detected with the full chain: `dependency cycle: A -> B -> A`.

## Scopes

```gdscript
var level_scope: TrServiceContainer = app_container.create_scope()
level_scope.scoped(EnemySpawner, func(s: TrServiceContainer) -> EnemySpawner: return EnemySpawner.new())
level_scope.instance(LevelClock, LevelClock.new())   # overrides or extends the parent
# ... on scene change:
level_scope.dispose()
```

- A scope sees every registration of its parents and can override them.
- Singletons always live in the container that registered them, even when a child scope resolves them first,
  so a singleton never captures a scope's services.
- `dispose()` disposes child scopes, then calls `dispose()` on objects the container created (if they have that
  method) and frees `Node`s that are outside the scene tree. Objects registered with `instance()` are never touched.

## Validation

`validate()` resolves every registration once, collects every problem (missing registrations, cycles, wrong
types) without printing errors, and returns one `TrResult`. Singletons stay created. Scoped and transient services
are created in a temporary scope that is disposed. Call it once at startup and fail fast.

## Injecting nodes

`TrInjector` calls `_inject(c: TrServiceContainer)` on nodes before their `_ready()`. With the Truss plugin
enabled, `Truss.boot()` sets it up automatically; see the [modules guide](modules.md#the-truss-autoload-and-automatic-injection).
