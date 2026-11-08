@tool
class_name TrDebugPanel
extends VBoxContainer
## The "Truss" tab of the editor's Debugger panel: modules and services of the running game, plus a log of
## recent events and requests. Filled by [method apply] with the messages sent by [TrDebugReporter].

const MAX_LOG: int = 200

var _summary: Label
var _tree: Tree
var _log: ItemList
var _clear: Button
var _log_count: int = 0
var _phases: Dictionary[String, String] = {}


func _init() -> void:
	name = "Truss"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bar := HBoxContainer.new()
	_summary = Label.new()
	_summary.text = "Run the game from the editor to see Truss data."
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clear = Button.new()
	_clear.text = "Clear log"
	_clear.pressed.connect(clear_log)
	bar.add_child(_summary)
	bar.add_child(_clear)
	add_child(bar)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree = Tree.new()
	_tree.columns = 2
	_tree.hide_root = true
	_tree.custom_minimum_size = Vector2(260, 120)
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log = ItemList.new()
	_log.custom_minimum_size = Vector2(260, 120)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_tree)
	split.add_child(_log)
	add_child(split)


## Handles one "truss:*" message. [param message] is the part after the prefix ("boot", "event", "request").
## Returns [code]false[/code] for unknown messages.
func apply(message: String, data: Array) -> bool:
	match message:
		"boot":
			_show_boot(data)
		"event":
			_add_log("event   %s" % str(data[0]) if data.size() > 0 else "event")
		"request":
			_add_log(_request_line(data))
		"phase":
			_show_phase(data)
		"pause":
			var paused: bool = data[0] if data.size() > 0 else false
			var holders: PackedStringArray = data[1] if data.size() > 1 else PackedStringArray()
			_add_log("pause   %s%s" % ["ON " if paused else "OFF", (" (" + ", ".join(holders) + ")") if not holders.is_empty() else ""])
		_:
			return false
	return true


func clear_log() -> void:
	_log.clear()
	_log_count = 0


## For tests and tools: the number of lines in the log, and their text.
func log_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for i: int in _log.item_count:
		out.append(_log.get_item_text(i))
	return out


## For tests and tools: "Modules"/"Services" sections as text lines ("Section/Item | detail").
func tree_lines() -> PackedStringArray:
	var out := PackedStringArray()
	var root: TreeItem = _tree.get_root()
	if root == null:
		return out
	for section: TreeItem in root.get_children():
		for item: TreeItem in section.get_children():
			out.append("%s/%s | %s" % [section.get_text(0), item.get_text(0), item.get_text(1)])
	return out


func summary_text() -> String:
	return _summary.text


func _show_boot(data: Array) -> void:
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var modules: PackedStringArray = data[0] if data.size() > 0 else PackedStringArray()
	var services: Array = data[1] if data.size() > 1 else []
	var module_section: TreeItem = _tree.create_item(root)
	module_section.set_text(0, "Modules")
	for i: int in modules.size():
		var item: TreeItem = _tree.create_item(module_section)
		item.set_text(0, modules[i])
		item.set_text(1, "#%d" % (i + 1))
	var service_section: TreeItem = _tree.create_item(root)
	service_section.set_text(0, "Services")
	for entry: Variant in services:
		var pair: Array = entry
		var item: TreeItem = _tree.create_item(service_section)
		item.set_text(0, str(pair[0]))
		item.set_text(1, str(pair[1]))
	_summary.text = "%d modules, %d services" % [modules.size(), services.size()]
	_rebuild_phases(root)
	clear_log()


func _show_phase(data: Array) -> void:
	if data.size() < 3:
		return
	var machine: String = str(data[0])
	var previous: String = str(data[1])
	_phases[machine] = str(data[2])
	_add_log("phase   %s: %s%s" % [machine, (previous + " -> ") if not previous.is_empty() else "", _phases[machine]])
	var root: TreeItem = _tree.get_root()
	if root == null:
		root = _tree.create_item()
		_summary.text = "Truss running (no boot)"
	_rebuild_phases(root)


## The "Phases" section: the current phase of every TrPhases that reported a transition.
func _rebuild_phases(root: TreeItem) -> void:
	for section: TreeItem in root.get_children():
		if section.get_text(0) == "Phases":
			section.free()
	if _phases.is_empty():
		return
	var phase_section: TreeItem = _tree.create_item(root)
	phase_section.set_text(0, "Phases")
	for machine: String in _phases:
		var item: TreeItem = _tree.create_item(phase_section)
		item.set_text(0, machine)
		item.set_text(1, _phases[machine])


func _request_line(data: Array) -> String:
	if data.size() < 5:
		return "request"
	var ok: bool = data[1]
	var usec: int = data[3]
	var is_async: bool = data[4]
	return "request %s %s%s (%d µs)%s" % [str(data[0]), "ok" if ok else "FAILED ", "" if ok else str(data[2]), usec, " async" if is_async else ""]


func _add_log(line: String) -> void:
	_log_count += 1
	_log.add_item("%d  %s" % [_log_count, line])
	while _log.item_count > MAX_LOG:
		_log.remove_item(0)
	_log.ensure_current_is_visible()
