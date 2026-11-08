# Changelog

All notable changes to Truss are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/). Until 1.0, minor versions may break the API.

## [Unreleased] — 0.4.0 (milestone M4)

### Added
- `fsm`: `TrStateMachine` and `TrState`: hierarchical states as nodes, transitions by class, initial states and
  substates, queued transitions, parent-first updates, input bubbling, `history`, `transitioned` signal.
- `TrMediator.send_async()` and `TrBehavior.process_async()` for handlers that `await`. `send()` reports
  asynchronous handlers with the `async_handler` error.
- Editor: a **Truss** tab in the Debugger panel (`TrDebugPanel`, `TrDebugReporter`, `tr_debugger_plugin.gd`)
  with modules, services, events and requests of the running game.
- `TrEventBus.published` signal.
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
