# RFC 0001 — Truss: an architecture framework for GDScript

| | |
|---|---|
| Status | **Accepted** (milestone M0) |
| Date | 2026-11-08 |
| Name | Truss (class prefix `Tr`) |
| License | MIT |
| Minimum Godot | 4.5 (for `@abstract`) |
| Repository | `jsperez852/truss` |
| Related | The `godot-architecture` plugin in [godot-market-place](https://github.com/jsperez852/godot-market-place), which teaches the patterns Truss implements |

## 1. Summary

Truss is a pure-GDScript addon (`res://addons/truss/`) that gives a Godot project the building blocks of a
structured architecture that the language doesn't provide:
- contracts checked by the engine;
- dependency injection from a composition root;
- typed messaging: events, plus commands and queries through a mediator;
- `TrResult` for expected errors;
- feature modules with ordered startup;
- a strict typing profile;
- tooling: a layer linter, generators and an editor panel.

It doesn't change the language or the engine. It adds structure through **conventions + a library + tooling**, and it
keeps scenes and the inspector first-class.

## 2. Motivation

GDScript is fast for prototyping, but mid-sized projects keep running into the same problems:
- autoloads used as global state;
- game logic trapped in nodes, which can't be tested without scenes;
- implicit dependencies through node paths;
- signals and calls by string name, whose errors only show up at runtime.

C# has interfaces and generics, but it can't export to Web, and most of the community writes GDScript.

### Prior art

| Project | Approach | Difference from Truss |
|---|---|---|
| [GF Framework](https://github.com/c76gn/gf-framework) (Apache-2.0, Godot 4.7+) | Model / System / Controller / Utility layers registered on a `Gf` autoload; events, commands, queries, state machines, many optional extensions, editor workspace | Dependencies are looked up from a global architecture object (`Gf.get_model()`, a service locator). Truss uses `@abstract` ports checked at load time, injection from a composition root with startup validation, a mediator with pipeline behaviors, feature-sliced layers, and supports Godot 4.5+ |
| Single-purpose DI addons (Simple Dependency Injection, DI: Dependency Injector) | Containers configured in the inspector or in code | One piece only; no contracts, messaging or boundary checks |
| [Godot Traits](https://github.com/Earewien/godot-traits), GDScript Interfaces | Emulate traits or interfaces on top of GDScript (Godot Traits uses comment annotations and generated helpers) | Truss relies on the native `@abstract` check instead of emulation |

Truss is for developers who want hexagonal / Clean Architecture in GDScript with explicit dependencies. Teams who
prefer a batteries-included layered toolkit should look at GF.

## 3. Language constraints (verified on Godot 4.7.2)

| Fact | Design consequence |
|---|---|
| `@abstract` on classes and methods: an incomplete subclass fails to load, and `Abstract.new()` is a parse error | **Ports** are `@abstract` classes. They are the only contract the language checks |
| Single inheritance; no `interface`, `trait` or generics (`class X[T]` is a syntax error) | An object fulfils **one** contract through inheritance. Several capabilities means composition (one object per contract) |
| No custom annotations (`@inject` gives "Unrecognized annotation") | Injection is declared with a conventional method, `_inject(c)` |
| `@export` only accepts built-in types, `Resource`, `Node` or enums | `RefCounted` ports can't be exported; they're injected in code |
| `SceneTree.node_added` is emitted after `_enter_tree` and **before `_ready`**, parent before child | An injector can prepare every node before its `_ready`, including nodes in instanced scenes |
| `is_instance_of(obj, Script)` follows script inheritance | The container checks that an implementation fulfils its contract when it's resolved |
| Typed signal parameters aren't checked on `emit()` | Events are **classes**, not signal signatures |
| Typing warnings can be raised to errors (`untyped_declaration=2`, etc.) | The strict profile is a `project.godot` preset |
| Typed `Dictionary[Script, X]` works as a registry | Container and bus keys are the scripts themselves |
| An inner `enum State` clashes with a global `class_name State`; `class_name Container` fails with "hides a native class" | Every global Truss class uses the `Tr` prefix (`TrServiceContainer`, `TrResult`) |

## 4. Goals and non-goals

**Goals**
1. Game rules can be written and tested without scenes.
2. Wiring errors (unfulfilled contract, missing dependency, broken layer rule) appear at startup or in CI, not mid-game.
3. Zero cost in per-frame code: nothing in Truss runs every frame unless the user calls it.
4. Gradual adoption: use only `TrResult`, or only the event bus, without the rest.
5. Everything stays readable in Godot's inspector and debugger.

**Non-goals**
- Replacing nodes, scenes or local signals.
- An ECS. Thousands of entities belong to the Servers, which are out of scope.
- Reflection magic or runtime code generation.
- Supporting Godot 4.4 or older.

## 5. Principles

1. **Explicit over magic.** Every dependency is visible in code (`_inject`, `register`), never by string name.
2. **The engine first.** If Godot already solves it (local signals, Resources, scenes), Truss doesn't wrap it.
3. **Fail fast.** Validate at registration and startup, with messages that say what is missing and where.
4. **Every piece is optional** and depends only on `core`.
5. **Proportional.** The docs say when *not* to use each piece.

## 6. Design

API sketches below were the proposals made in M0. The implemented API (M1: `core`, `di`, `messaging`; M2: `modules`, injector) is documented in
[docs/guide](../guide/) and may differ in details; for example, factories receive the resolving container as an argument
because capturing the container in a lambda creates a reference cycle.

```
addons/truss/
  plugin.cfg, plugin.gd       editor panel (optional)
  core/                       TrResult, TrOption, TrContracts
  di/                         TrServiceContainer, TrScope, TrInjector
  messaging/                  TrEvent, TrEventBus, TrRequest, TrRequestHandler, TrMediator, TrBehavior
  modules/                    TrModule, TrBootstrap
  fsm/                        TrStateMachine, TrState (hierarchical)
  tooling/                    arch_check.gd, strict_profile.cfg, generators
```

### 6.1 core: results and contracts

```gdscript
var r: TrResult = TrResult.success(value)      # or TrResult.failure(&"inventory_full", "details")
if r.is_err(): return r                        # explicit propagation
var v: int = r.unwrap_or(0)
TrContracts.require(impl, InventoryStore)      # assert with a clear message if impl doesn't fulfil it
```

`TrResult` is a `RefCounted` with `ok`, `value`, `error: StringName` and `message`. Without generics the value is a
`Variant`; the docs recommend casting at the edge (`r.value as ItemDef`).

### 6.2 di: container, scopes and injector

```gdscript
var c := TrServiceContainer.new()
c.singleton(InventoryStore, func() -> InventoryStore: return ConfigInventoryStore.new("user://inv.cfg"))
c.transient(AddItem, func(s: TrServiceContainer) -> AddItem: return AddItem.new(s.get_service(Inventory), s.get_service(InventoryStore)))
c.instance(Clock, SystemClock.new())

var store := c.get_service(InventoryStore) as InventoryStore
```

- Keys are scripts. Resolution checks `is_instance_of(result, key)`.
- Scopes: `app` (root) and `scene` (child, released with the current scene). `c.create_scope()` returns a child that inherits registrations.
- Cycle detection during resolution, with the full chain in the error (`A -> B -> A`).
- `c.validate()` resolves every singleton at startup to fail fast.
- **Automatic injection, can be turned off** (decision D4). The `Truss` autoload listens to `node_added`. If the node
  has `func _inject(c: TrServiceContainer) -> void`, it's called before the node's `_ready`. A project setting
  (`truss/injection/automatic`) turns it off; then `TrInjector.inject(node)` does it explicitly. Nodes can still
  receive other nodes or Resources through `@export`.

```gdscript
extends Control

var _add_item: AddItem

func _inject(c: TrServiceContainer) -> void:
	_add_item = c.get_service(AddItem) as AddItem
```

### 6.3 messaging: events, commands, queries

- `TrEvent` (abstract) for past-tense facts. `TrEventBus` subscribes by class, dispatches to base classes as well,
  and drops handlers whose object was freed. It extends the bus from the `godot-architecture` plugin.
- `TrRequest` for commands and queries. `TrMediator.send(request) -> TrResult` finds the **one** handler registered for that class.
- `TrBehavior`: a pipeline around every `send`, like MediatR's pipeline behaviors. For logging, validation,
  undo/replay and timing.
- Asynchronous handlers (`send_async` with `await`) are deferred to **M4** (decision D5).

```gdscript
class_name AddItemRequest extends TrRequest
var item: ItemDef
var amount: int

class_name AddItemHandler extends TrRequestHandler
func handles() -> Script: return AddItemRequest
func handle(r: TrRequest) -> TrResult:
	var req := r as AddItemRequest
	return _inventory.add(req.item, req.amount)
```

Documented rule: the mediator is for **player and AI actions**, not for per-frame movement.

### 6.4 modules: features with ordered startup

```gdscript
class_name InventoryModule extends TrModule
func dependencies() -> Array[Script]: return [SaveModule]
func register(c: TrServiceContainer) -> void:
	c.singleton(Inventory, func() -> Inventory: return Inventory.new(20))
	c.singleton(InventoryStore, func() -> InventoryStore: return ConfigInventoryStore.new("user://inv.cfg"))
	mediator.handle(AddItemHandler.new(c))
func start(c: TrServiceContainer) -> void: pass      # after every module registered
```

`TrBootstrap` (the composition root) takes the module list and sorts it topologically. A cycle fails with its path.
It calls `register` on every module, then `start`, then `validate()`. Tests can boot a subset of modules and override registrations.

### 6.5 fsm

A node-based hierarchical state machine with a transition history visible in the inspector. It builds on the
`godot-architecture` catalog, with `@abstract` states and transitions by state class instead of by string name.

### 6.6 tooling

- **`strict_profile.cfg`**: the recommended `[debug]` block (typing, unsafe casts and unsafe access as errors), plus a
  script that merges it into `project.godot` after confirmation.
- **`arch_check.gd`**: the plugin's checker, extended with cross-feature rules (only `domain` and `application` are
  public to other features) and JUnit output for CI.
- **Generators** (tool scripts plus marketplace skills): new module, use case + request + handler, port + adapter, event.
- **Editor panel** (M4): loaded modules, container registrations, recent events and requests.

## 7. Performance

- Budget: `TrEventBus.publish` and `TrMediator.send` in the microsecond range per call with few handlers. Measured
  against a native signal in M1, with the table published in the docs.
- Nothing is registered in `_process`. The injector only reacts to `node_added`, and can be turned off.
- Singleton resolution is cached. A transient costs one `Callable` call.

## 8. Quality and distribution

- Truss's own tests use **gdUnit4** (decision D6). CI runs a Godot 4.5 / 4.6 / 4.7 matrix on GitHub Actions, reusing
  the `godot-ci` templates from the marketplace.
- SemVer, breaking changes only in major versions, a CHANGELOG.
- Distribution: GitHub releases with the addon zip, the Godot Asset Library, and git submodule for those who prefer it.
- Docs in English with a Spanish summary in the README (decision D7): install in three steps, a guide per piece, and a
  small example game (a single-room roguelite) that uses every piece and passes `arch_check`.
- A `godot-truss` plugin in the marketplace: a skill that teaches Claude to use Truss and its generators.

## 9. Milestones

| Milestone | Content | Exit criteria |
|---|---|---|
| M0 | This RFC accepted, name and license decided, repository created | Decisions in section 11 closed ✅ |
| M1 ✅ | `core` + `di` + synchronous `messaging` + benchmarks | Tests green on 4.5 and 4.7, performance table |
| M2 ✅ | `modules` + `TrBootstrap` + injector + minimal example | The example boots, and fails clearly on a cycle or a missing registration |
| M3 | `tooling`: strict profile, `arch_check` v2, generators, marketplace skill | Example CI runs `arch_check` |
| M4 | `fsm` + editor panel + `send_async` | Complete example game |
| 1.0 | Frozen API, complete docs, Asset Library | API and docs review |

## 10. Risks and alternatives

| Risk | Mitigation |
|---|---|
| Over-engineering small games | Optional pieces and a "when not to use it" guide. The example stays small |
| Cost of indirection | M1 benchmarks and the "nothing per frame" rule |
| Friction with the editor workflow | Scenes runnable alone (F6) with a test container; `@export` keeps working |
| GDScript changes (traits, if they ship) | A small contracts layer, reviewed every Godot minor release. Contracts can move to traits without breaking the API |
| Single maintainer | Scope limited until 1.0, and CI covering every supported Godot version |

Rejected alternatives:
- **Use C#**: no Web export, and it leaves GDScript users out.
- **Build on GF Framework**: different philosophy (global locator vs. ports and injection) and Godot 4.7+ only. Truss
  stays complementary and its docs point to GF for teams who prefer that model.
- **Adopt an existing DI addon**: covers one piece, with no maintenance guarantee.
- **GDExtension in C++**: per-platform builds with no clear gain for this scope.

## 11. Decisions (closed in M0)

| # | Question | Decision |
|---|---|---|
| D1 | Name | **Truss**, the triangulated frame that holds up bridges and roofs: small parts that carry a lot together |
| D2 | License | **MIT** |
| D3 | Global class names | **`Tr` prefix** on every global class (`TrResult`, `TrServiceContainer`, `TrEventBus`) |
| D4 | Node injection | **Automatic via `node_added`, can be turned off** with a project setting; explicit `TrInjector.inject()` always available |
| D5 | Async handlers | **M4** |
| D6 | Test framework for Truss itself | **gdUnit4** |
| D7 | Documentation language | **English, with a Spanish summary** in the README |
| D8 | Repository | `jsperez852/truss`, created by Claude with the user's approval |
| D9 | Strategy vs. GF Framework | **Differentiated framework**: ports, composition-root injection, mediator pipelines, feature slices, Godot 4.5+ |
