# Changelog

All notable changes to Truss are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/). Until 1.0, minor versions may break the API.

## 0.6.0 — 2026-11-08 (RFC 0003)

### Added
- `economy`: `TrWallet` (currencies, `try_spend` returning `TrResult`, all-or-nothing `try_spend_all`, `changed`
  signal, `snapshot`/`restore`) and `TrCurve` (exponential, linear or table growth, rounding once or at every
  level, milestones, `total`, `max_affordable`), a Resource tuned in the inspector.
- `save`: `TrSave` (one Dictionary per file, atomic write with a `.bak` backup, versions and migrations, fallback
  to the backup, `read_or` with defaults, optional encryption; never stores objects).
- `TrPhases` reports transitions to the editor's Truss debugger tab (log and a "Phases" section), without
  `Truss.boot()`. `TrPhases.new(name)`.
- `TrEventBus.unsubscribe(type, handler, source)` removes one source's subscription.
- Guides: [economy](docs/guide/economy.md), [save](docs/guide/save.md); Truss Lite uses `TrSave`, `TrWallet` and `TrCurve`.

### Fixed
- `TrEventBus.subscribe()` treated the same handler with a different `source` as a duplicate, so one shared
  Resource listening to several characters only received the first one's events (found migrating gradma-tale).

## 0.5.1 — 2026-11-08 (pilot adjustments)

Adjustments from migrating four real projects (Pong, Flappy-style, platformer, idle tycoon) to Truss.

### Added
- `fsm`: `TrPhases`, a phase machine written in code (`add` with `enter`/`exit`/`update`/`to`, `start`, `go`,
  `can_go`, `elapsed`, `changed`), for game phases that don't need a node per state.
- `TrEventBus`: handlers may take no argument; option `outside_tree`.
- `TrRegistry.new()` accepts native Resource classes (`TrRegistry.new(Curve)`) and class names (`&"Curve"`).
- `generate.gd event <feature> <Name> field:Type ...` writes typed fields and the `_init` that sets them.
- Truss Lite guide: level 0 ("you don't need Truss") and `TrPhases` at level 1.

### Changed
- `TrEventBus`: handlers bound to a Node are skipped while the node is outside the scene tree (they resume when it
  returns). Freed nodes were already dropped, so the guides no longer ask for an `_exit_tree()` unsubscribe.
  Pass `{outside_tree = true}` for the previous behavior.
- `TrEventBus.subscribe()` rejects handlers with two or more arguments instead of failing on publish.

## 0.5.0 — 2026-11-08 (RFC 0002)

### Added
- `content`: `TrRegistry` (scan with `ResourceLoader.list_directory`, `by_id`, `where`, `pick_weighted`,
  `instantiate` with `duplicate_deep`, `skipped`), with `tools/test_export.sh` checking an exported `.pck` in CI.
- `stats`: `TrStat` (cached `(base + flat) × (1 + Σ percent) × Π multiply` with limits, `changed` only on real
  changes, weakly referenced object sources), `TrModifier`, `TrStats` (declared keys, errors listing valid names,
  `remove_from` across stats, `snapshot`) and `TrModifierDef` for inspector-authored modifiers.
- `time`: `TrPause` / `TrPauseToken` as `Truss.pause` (tokens, restore of the previous pause state, tokens
  released when freed, stacking `hit_stop` relative to the game's time scale, `reset`), `TrAppEvents` published on
  the bus and emitted as `Truss.app_event`, setting `truss/lifecycle/pause_on_focus_loss`, and pause changes in
  the debugger tab.
- `TrEventBus.subscribe(type, handler, {priority, source})` and `publish(event, source)`: priority across the class
  hierarchy, source filtering, `TrEvent.source`, cached dispatch order.
- `TrStateMachine.transition_to(state, args)` with `transition_args`, and `send_intent(intent, data)` with
  `TrState.handle_intent()` bubbling from the leaf.
- `arch_check` rule `stateful_resources` (off by default): Resource scripts with non-exported fields.
- `Truss.boot()` registers `Truss.pause` in the container as `TrPause`.
- Truss Lite guide (three adoption levels) and `tools/check_doc_snippets.sh`, run in CI.
- `examples/arena` uses `TrRegistry` (enemy types), `TrStats` (player upgrades per wave), hit stop, a pause token
  and event priority.

### Changed
- `TrContracts.describe()` names inner classes of named scripts `Outer.Inner` (also nested), so modules and events
  declared as inner classes get readable names in boot messages and the debugger tab.

## 0.4.0 (milestone M4)

### Added
- `fsm`: `TrStateMachine` and `TrState`: hierarchical states as nodes, transitions by class, initial states and
  substates, queued transitions, parent-first updates, input bubbling, `history`, `transitioned` signal.
- `TrMediator.send_async()` and `TrBehavior.process_async()` for handlers that `await`. `send()` reports
  asynchronous handlers with the `async_handler` error.
- Editor: a **Truss** tab in the Debugger panel (`TrDebugPanel`, `TrDebugReporter`, `tr_debugger_plugin.gd`)
  with modules, services, events and requests of the running game.
- `TrEventBus.published` signal, emitted before the handlers run so nested events keep their order.
- `examples/arena` game and `tools/run_arena.sh` (autoplay, record saving, `arch_check`), run in CI.
- 114 gdUnit4 tests.

## 0.3.0 (milestone M3)

### Added
- `tooling/strict_profile.gd`: dry run or `--apply` of the strict typing profile, `--level=warn`, `--include-addons`
  using `directory_rules` (4.7+) or `exclude_addons` (4.5).
- `tooling/generate.gd`: `module`, `usecase`, `port` and `event` generators that never overwrite and produce
  strict-clean code.
- `tooling/arch_check.gd` (v2 of the marketplace checker): feature boundaries, forbidden classes per layer, JUnit
  output, `--write-default-config`, exit code 2 for configuration errors.
- `tools/test_tooling.sh`, run in CI on Godot 4.5.1 and 4.7.2.
- The `godot-truss` plugin in godot-market-place.

## 0.2.0 (milestone M2)

### Added
- `modules`: `TrModule` (`dependencies`, `register`, `start`, `stop`, `module_name`) and `TrBootstrap`
  (dependency ordering, missing-dependency, cycle and duplicate detection, container validation before any
  `start`, `shutdown` in reverse order).
- `TrInjector`: calls `_inject(c)` before `_ready()` through `SceneTree.node_added`, once per node; explicit
  `inject` / `inject_tree`; switchable container for scopes.
- `Truss` autoload and editor plugin (`plugin.cfg`), with the `truss/injection/automatic` project setting.
- `examples/minimal` with `tools/run_example.sh`, which checks the normal run and three failure modes.
- 90 gdUnit4 tests.

### Changed
- `TrContracts.describe()` names unnamed scripts (inner classes) by their first named base class.
- `TrBootstrap.add_all()` and `Truss.boot()` accept any `Array` of modules, so array literals work from dynamic calls.

## 0.1.0 (milestone M1)

### Added
- `core`: `TrResult` (success/failure, `unwrap`, `unwrap_or`, `map`, `and_then`), `TrOption`, `TrContracts`
  (`implements`, `require`, `describe`, `describe_value`; safe with freed objects).
- `di`: `TrServiceContainer` with singleton, scoped, transient and instance lifetimes, child scopes with overrides,
  contract checks on every resolution, cycle detection with the full chain, `validate()` that collects every
  problem, and `dispose()`.
- `messaging`: `TrEvent` and `TrEventBus` (subscription by class, base-class delivery, freed-handler cleanup,
  `unsubscribe_all`); `TrRequest`, `TrRequestHandler`, `TrMediator` and `TrBehavior` pipelines.
- 67 gdUnit4 tests, passing on Godot 4.5.1 and 4.7.2.
- Strict typing profile for Truss's own code (`directory_rules`, Godot 4.7+), `tools/compile_check.gd`,
  `tools/bench.gd` and a GitHub Actions matrix for Godot 4.5.1 and 4.7.2.
