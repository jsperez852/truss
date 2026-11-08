# Getting started: a small game in 15 minutes

You'll build a 30-second clicker: click to earn coins, buy upgrades that cost more each level, and keep the best
score between sessions. Along the way you use the five pieces most games need first: typed events
(`TrEventBus`), game phases (`TrPhases`), a balance (`TrWallet`), prices per level (`TrCurve`) and a save file
(`TrSave`). No modules or dependency injection: that's [Truss Lite](lite.md) level 1–2.

Requires Godot 4.5 or later.

## 1. Install

- **Asset Library**: in the editor, open the **AssetLib** tab, search "Truss", download and install.
- **Or by hand**: download `truss-<version>.zip` from the [releases](https://github.com/jsperez852/truss/releases)
  and copy `addons/truss` into your project's `addons/` folder.

Then open **Project → Project Settings → Plugins** and enable **Truss**. It adds a `Truss` autoload and a
**Truss** tab to the Debugger panel.

## 2. Events

Events are classes, so a typo is a parse error instead of a signal that silently never fires. Put the game's
events in one file:

```gdscript
# file: res://events.gd
class_name Events
extends RefCounted


class CoinsChanged:
	extends TrEvent
	var coins: float

	func _init(p_coins: float) -> void:
		coins = p_coins


class RoundOver:
	extends TrEvent
	var score: float
	var best: float

	func _init(p_score: float, p_best: float) -> void:
		score = p_score
		best = p_best
```

## 3. The game autoload

One autoload holds the bus, the wallet and the save file. Add it in **Project Settings → Globals** as `Game`.

```gdscript
# file: res://game.gd (autoload "Game")
extends Node

var bus := TrEventBus.new()
var wallet := TrWallet.new()
var save := TrSave.new("user://clicker.save")
var best: float = 0.0


func _ready() -> void:
	best = save.read_or({"best": 0.0})["best"]
	wallet.changed.connect(func(_currency: StringName, _old: float, coins: float) -> void:
		bus.publish(Events.CoinsChanged.new(coins)))


## Saves the score when it beats the record. Returns true for a new record.
func finish_round(score: float) -> bool:
	var record: bool = score > best
	if record:
		best = score
		var written: TrResult = save.write({"best": best})
		if written.is_err():
			push_warning(written.message)
	bus.publish(Events.RoundOver.new(score, best))
	return record
```

`save.write()` never leaves a half-written file: it writes a temporary file, keeps the previous save as a backup
and then swaps them. `read_or()` returns the defaults when there's no save yet.

## 4. The main scene

Create a scene with a `Control` root (Full Rect) and attach this script. It builds its own UI, so there's nothing
else to set up.

```gdscript
# file: res://main.gd
extends Control

const ROUND_SECONDS: float = 30.0

var phase := TrPhases.new(&"round")
var level: int = 0
var per_click: float = 1.0
var upgrade_cost := TrCurve.exponential(10.0, 1.15)

var _click := Button.new()
var _upgrade := Button.new()
var _status := Label.new()


func _ready() -> void:
	upgrade_cost.rounding = TrCurve.Rounding.CEIL
	_build_ui()
	phase.add(&"title", {enter = _on_title, to = [&"playing"]})
	phase.add(&"playing", {enter = _on_playing, update = _on_playing_update, to = [&"over"]})
	phase.add(&"over", {enter = _on_over, to = [&"title"]})
	phase.start(&"title")


func _process(delta: float) -> void:
	phase.update(delta)


func _on_title() -> void:
	_status.text = "Best: %d. Click to start." % Game.best
	_upgrade.disabled = true


func _on_playing() -> void:
	level = 0
	per_click = 1.0
	Game.wallet.set_balance(0.0)
	_upgrade.disabled = false
	_refresh_upgrade()


func _on_playing_update() -> void:
	_status.text = "%.0f s left" % maxf(ROUND_SECONDS - phase.elapsed(), 0.0)
	if phase.elapsed() >= ROUND_SECONDS:
		phase.go(&"over")


func _on_over() -> void:
	var record: bool = Game.finish_round(Game.wallet.balance())
	_status.text = ("New record! " if record else "") + "Click to play again."
	_upgrade.disabled = true


func _on_click_pressed() -> void:
	if phase.is_in(&"title"):
		phase.go(&"playing")
	elif phase.is_in(&"playing"):
		Game.wallet.earn(per_click)
	else:
		phase.go(&"title")


func _on_upgrade_pressed() -> void:
	var paid: TrResult = Game.wallet.try_spend(upgrade_cost.value_at(level))
	if paid.is_err():
		_status.text = paid.message      # "not enough coins: needs 12, has 7"
		return
	level += 1
	per_click += 1.0
	_refresh_upgrade()


func _refresh_upgrade() -> void:
	_upgrade.text = "Upgrade (+1 per click): %d coins" % upgrade_cost.value_at(level)


func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(box)
	_click.text = "Click!"
	_click.pressed.connect(_on_click_pressed)
	_upgrade.pressed.connect(_on_upgrade_pressed)
	var hud := preload("res://hud.gd").new()
	for node: Control in [_status, hud, _click, _upgrade]:
		box.add_child(node)
```

What to notice:

- `TrPhases` replaces a handful of `is_playing` / `is_over` flags. `to` lists the phases allowed next, so an
  impossible transition is refused instead of breaking the game. `elapsed()` is the time spent in the phase.
- `try_spend()` checks and pays in one call and says why it failed. There's no separate `if coins >= cost`.
- `TrCurve` is the price per level: 10, 12, 14, 16, 18, 21... Make it an `@export var upgrade_cost: TrCurve` to
  tune it in the inspector instead.

## 5. A label that listens

```gdscript
# file: res://hud.gd
extends Label


func _ready() -> void:
	Game.bus.subscribe(Events.CoinsChanged, _on_coins_changed)
	Game.bus.subscribe(Events.RoundOver, _on_round_over)


func _on_coins_changed(event: Events.CoinsChanged) -> void:
	text = "Coins: %d" % event.coins


func _on_round_over() -> void:      # a handler can skip the event when it doesn't need it
	modulate = Color(1.0, 0.85, 0.3)
```

There's no `_exit_tree()` to unsubscribe: handlers of freed nodes are dropped, and nodes outside the tree are
skipped.

## 6. Run it

Press **F5** and play a round. Then open the **Debugger** panel's **Truss** tab: the log shows
`phase round: title -> playing`, and the "Phases" section shows the current phase. Close the game, run it
again, and the best score is still there.

## Next steps

- [Truss Lite](lite.md): when to add content databases, stats and pause tokens (level 2), and when a game needs
  modules (level 3).
- [economy](economy.md) and [save](save.md): multi-currency prices, "buy max", save versions and migrations.
- [fsm](fsm.md): node-based state machines for characters and AI.
- `examples/arena` in the repository: a complete level-3 game.
