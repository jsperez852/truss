class_name TrInjector
extends RefCounted
## Calls [code]_inject(c: TrServiceContainer)[/code] on nodes before their [code]_ready()[/code].
##
## A node opts in by declaring the method:
## [codeblock]
## extends Control
##
## var _add_item: AddItem
##
## func _inject(c: TrServiceContainer) -> void:
##     _add_item = c.get_service(AddItem) as AddItem
## [/codeblock]
## Attached to a [SceneTree], the injector listens to [signal SceneTree.node_added], which Godot emits after
## [code]_enter_tree()[/code] and before [code]_ready()[/code], parent before children. Each node is injected
## once, even if it leaves and re-enters the tree. Without attaching, call [method inject] yourself.

const INJECT_METHOD: StringName = &"_inject"
const INJECTED_META: StringName = &"_tr_injected"

var _container: TrServiceContainer
var _tree: SceneTree
var _injected_count: int = 0


func _init(container: TrServiceContainer) -> void:
	_container = container


## Starts injecting every node added to [param tree]. Nodes already in the tree are not touched; use
## [method inject_tree] for them.
func attach(tree: SceneTree) -> void:
	if _tree == tree:
		return
	detach()
	_tree = tree
	_tree.node_added.connect(_on_node_added)


## Stops automatic injection.
func detach() -> void:
	if _tree != null and _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.disconnect(_on_node_added)
	_tree = null


func is_attached() -> bool:
	return _tree != null


## Injects [param node] if it declares [code]_inject[/code] and wasn't injected yet. Returns [code]true[/code]
## when [code]_inject[/code] was called.
func inject(node: Node) -> bool:
	if node == null or not node.has_method(INJECT_METHOD) or node.has_meta(INJECTED_META):
		return false
	if _container == null or _container.is_disposed():
		push_error("TrInjector: no usable container to inject %s" % node.get_path())
		return false
	node.set_meta(INJECTED_META, true)
	node.call(INJECT_METHOD, _container)
	_injected_count += 1
	return true


## Injects [param root] and all its descendants (parents before children). Returns how many were injected.
func inject_tree(root: Node) -> int:
	var count: int = 1 if inject(root) else 0
	for child: Node in root.get_children(true):
		count += inject_tree(child)
	return count


## Changes the container used for the next injections, for example to a scene scope.
func set_container(container: TrServiceContainer) -> void:
	_container = container


func get_container() -> TrServiceContainer:
	return _container


## How many nodes this injector has injected.
func injected_count() -> int:
	return _injected_count


func _on_node_added(node: Node) -> void:
	inject(node)
