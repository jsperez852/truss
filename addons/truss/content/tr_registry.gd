class_name TrRegistry
extends RefCounted
## A content database: loads every Resource of one type from a folder and gives typed lookups.
##
## [codeblock]
## var attacks := TrRegistry.new(BaseAttack)   # a Resource script; native classes work too: TrRegistry.new(Curve)
## var scan: TrResult = attacks.scan("res://data/attacks")
## if scan.is_err():
##     push_error(scan.message)
## var slash := attacks.by_id(&"slash") as BaseAttack
## var basics: Array[Resource] = attacks.where(func(a: BaseAttack) -> bool: return a.is_basic_attack)
## var loot := attacks.pick_weighted(rng, func(a: BaseAttack) -> float: return a.drop_weight) as BaseAttack
## var mine := attacks.instantiate(&"slash") as BaseAttack   # private deep copy for runtime state
## [/codeblock]
## Uses [method ResourceLoader.list_directory], so it also works in exported builds, where
## [method DirAccess.get_files_at] returns [code]*.tres.remap[/code] names instead of the original files.
## Definitions returned by [method all], [method by_id] and [method where] are shared: treat them as read-only
## and call [method instantiate] when something needs its own state.

const ERR_SCAN: StringName = &"scan_failed"
const ERR_NOT_A_FOLDER: StringName = &"not_a_folder"

var _type: Variant
var _type_name: String
var _id_property: StringName
var _items: Array[Resource] = []
var _by_id: Dictionary[StringName, Resource] = {}
var _skipped: PackedStringArray = []


## [param type]: the Resource script or native Resource class to collect (subclasses included).
## [param id_property]: the property used as id when the resource has it; otherwise the file name is used.
func _init(type: Variant, id_property: StringName = &"id") -> void:
	_id_property = id_property
	if type is Script:
		var script: Script = type
		_type = script
		_type_name = TrContracts.describe(script)
		return
	if typeof(type) == TYPE_STRING or typeof(type) == TYPE_STRING_NAME:
		_type_name = str(type)
	else:
		_type_name = _native_name(type)
	if _type_name.is_empty() or not ClassDB.class_exists(_type_name) or not ClassDB.is_parent_class(_type_name, &"Resource"):
		push_error("TrRegistry.new(): %s is not a Resource script or class" % str(type))
		_type = null
		return
	_type = StringName(_type_name)


## Loads every resource of the registry's type under [param folder] (and its subfolders when
## [param recursive]). Resources of other types are skipped (see [method skipped]). Load failures and
## duplicate ids make the result a failure listing every problem; the valid resources are still added.
## Returns a success holding the number of resources added.
func scan(folder: String, recursive: bool = true) -> TrResult:
	var root: String = folder.trim_suffix("/")
	if not DirAccess.dir_exists_absolute(root) and ResourceLoader.list_directory(root).is_empty():
		return TrResult.failure(ERR_NOT_A_FOLDER, "%s is not a folder or is empty" % root)
	var problems := PackedStringArray()
	var added: int = 0
	for path: String in _list(root, recursive):
		var loaded: Resource = ResourceLoader.load(path)
		if loaded == null:
			problems.append("%s could not be loaded" % path)
			continue
		if not _accepts(loaded):
			_skipped.append(path)
			continue
		var r: TrResult = _add(loaded, _id_of(loaded, path), path)
		if r.is_err():
			problems.append(r.message)
		else:
			added += 1
	if not problems.is_empty():
		return TrResult.failure(ERR_SCAN, "\n".join(problems))
	return TrResult.success(added)


## Adds a resource built in code. [param id] defaults to the id property or the resource's file name.
func add(resource: Resource, id: StringName = &"") -> TrResult:
	if resource == null or not _accepts(resource):
		return TrResult.failure(ERR_SCAN, "%s is not a %s" % [TrContracts.describe_value(resource), _type_name])
	var key: StringName = id if id != &"" else _id_of(resource, resource.resource_path)
	return _add(resource, key, resource.resource_path)


## Every registered resource, in scan order (shared definitions).
func all() -> Array[Resource]:
	return _items.duplicate()


## The resource with [param id], or [code]null[/code].
func by_id(id: StringName) -> Resource:
	return _by_id.get(id, null)


func has(id: StringName) -> bool:
	return _by_id.has(id)


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_by_id.keys())
	return out


func size() -> int:
	return _items.size()


## Resources for which [param predicate] (a Callable taking the resource) returns [code]true[/code].
func where(predicate: Callable) -> Array[Resource]:
	var out: Array[Resource] = []
	for item: Resource in _items:
		if predicate.call(item):
			out.append(item)
	return out


## Picks one resource at random, weighted by [param weight] (a Callable returning a float; items with weight
## <= 0 are never picked). Pass [param candidates] to pick among a subset (for example the result of [method where]).
## Returns [code]null[/code] when nothing can be picked.
func pick_weighted(rng: RandomNumberGenerator, weight: Callable, candidates: Array[Resource] = []) -> Resource:
	var pool: Array[Resource] = candidates if not candidates.is_empty() else _items
	var weights := PackedFloat32Array()
	var total: float = 0.0
	for item: Resource in pool:
		var raw: float = weight.call(item)
		var w: float = maxf(raw, 0.0)
		weights.append(w)
		total += w
	if total <= 0.0:
		return null
	var roll: float = rng.randf() * total
	for i: int in pool.size():
		roll -= weights[i]
		if roll < 0.0 and weights[i] > 0.0:
			return pool[i]
	for i: int in range(pool.size() - 1, -1, -1):
		if weights[i] > 0.0:
			return pool[i]
	return null


## A private deep copy of the resource with [param id] ([method Resource.duplicate_deep]), for runtime state.
## Reports an error and returns [code]null[/code] for unknown ids.
func instantiate(id: StringName) -> Resource:
	var source: Resource = by_id(id)
	if source == null:
		push_error("TrRegistry(%s): no resource with id %s" % [_type_name, id])
		return null
	return source.duplicate_deep()


## Paths of files under the scanned folders that were resources of another type.
func skipped() -> PackedStringArray:
	return _skipped.duplicate()


func clear() -> void:
	_items.clear()
	_by_id.clear()
	_skipped.clear()


func _accepts(resource: Resource) -> bool:
	if _type is Script:
		return is_instance_of(resource, _type)
	return _type != null and resource.is_class(_type_name)


## The name of a native class reference such as [code]Curve[/code] (GDScript passes it as an object without a name).
static func _native_name(type: Variant) -> String:
	if typeof(type) != TYPE_OBJECT or type == null:
		return ""
	var native: Object = type
	if not native.has_method(&"new"):
		return ""
	var probe: Variant = native.call(&"new")
	if typeof(probe) != TYPE_OBJECT or probe == null:
		return ""
	var instance: Object = probe
	var found: String = instance.get_class()
	if not (instance is RefCounted):
		instance.free()
	return found


func _add(resource: Resource, id: StringName, path: String) -> TrResult:
	if id == &"":
		return TrResult.failure(ERR_SCAN, "%s has no id" % (path if not path.is_empty() else TrContracts.describe_value(resource)))
	if _by_id.has(id):
		var other: Resource = _by_id[id]
		return TrResult.failure(ERR_SCAN, "duplicate id %s in %s (already used by %s)" % [id, path, other.resource_path])
	_items.append(resource)
	_by_id[id] = resource
	return TrResult.success(resource)


func _id_of(resource: Resource, path: String) -> StringName:
	if _id_property != &"" and _id_property in resource:
		var value: Variant = resource.get(_id_property)
		if value != null and str(value) != "":
			return StringName(str(value))
	return StringName(path.get_file().get_basename()) if not path.is_empty() else &""


func _list(folder: String, recursive: bool) -> PackedStringArray:
	var out := PackedStringArray()
	var entries: PackedStringArray = ResourceLoader.list_directory(folder)
	for entry: String in entries:
		if entry.ends_with("/"):
			if recursive:
				out.append_array(_list(folder.path_join(entry.trim_suffix("/")), true))
		else:
			out.append(folder.path_join(entry))
	return out
