class_name TrContracts
extends RefCounted
## Helpers for contracts (ports) written as [code]@abstract[/code] classes.
##
## Godot already refuses to load a subclass that misses an abstract method. These helpers check the
## other half: that a given object really is an implementation of the contract you expect.


## [code]true[/code] when [param object] is an instance of [param contract] or of one of its subclasses.
static func implements(object: Variant, contract: Script) -> bool:
	# Check validity before any "is" test: "is" on a freed instance is a runtime error.
	if contract == null or typeof(object) != TYPE_OBJECT or not is_instance_valid(object):
		return false
	return is_instance_of(object, contract)


## Reports an error and returns [code]false[/code] when [param object] doesn't implement [param contract].
## [param context] is added to the message to say where the check happened.
static func require(object: Variant, contract: Script, context: String = "") -> bool:
	if implements(object, contract):
		return true
	push_error("%s%s does not implement %s" % [(context + ": ") if not context.is_empty() else "", describe_value(object), describe(contract)])
	return false


# Inner class -> "Outer.Inner", built on first use from the global class list.
static var _inner_names: Dictionary[Script, String] = {}
static var _inner_names_built: bool = false


## A readable name for a script: its [code]class_name[/code], or its path when it has none. Inner classes
## ([code]class Foo:[/code] inside a script) are named [code]Outer.Foo[/code] when the outer script has a
## [code]class_name[/code]; otherwise they are described by their first named base class, for example
## [code]<unnamed TrModule subclass>[/code].
static func describe(script: Script) -> String:
	if script == null:
		return "<null script>"
	var global_name: StringName = script.get_global_name()
	if global_name != &"":
		return String(global_name)
	if not script.resource_path.is_empty():
		return script.resource_path
	var inner_name: String = _inner_name(script)
	if not inner_name.is_empty():
		return inner_name
	var base: Script = script.get_base_script()
	while base != null:
		if base.get_global_name() != &"":
			return "<unnamed %s subclass>" % base.get_global_name()
		base = base.get_base_script()
	return "<anonymous script>"


## A readable description of any value, used in error messages.
static func describe_value(value: Variant) -> String:
	if typeof(value) == TYPE_OBJECT:
		if not is_instance_valid(value):
			return "<freed object>"
		var o: Object = value
		var script: Script = o.get_script() as Script
		return describe(script) if script != null else o.get_class()
	if value == null:
		return "null"
	return type_string(typeof(value))


## Forgets the inner-class name cache (after scripts are reloaded, for example by a tool).
static func clear_name_cache() -> void:
	_inner_names.clear()
	_inner_names_built = false


static func _inner_name(script: Script) -> String:
	if not _inner_names.has(script) and not _inner_names_built:
		_build_inner_names()
	return _inner_names.get(script, "")


static func _build_inner_names() -> void:
	_inner_names_built = true
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		var path: String = entry["path"]
		if not path.ends_with(".gd") or not ResourceLoader.exists(path):
			continue
		var outer: Script = load(path) as Script
		if outer != null:
			var outer_name: String = entry["class"]
			_index_inner_classes(outer, outer_name, 0)


static func _index_inner_classes(outer: Script, prefix: String, depth: int) -> void:
	if depth > 4:
		return
	var constants: Dictionary = outer.get_script_constant_map()
	for key: Variant in constants:
		var value: Variant = constants[key]
		if value is Script:
			var inner: Script = value
			# Only true inner classes have no path; preloaded scripts keep theirs and are named by it.
			if inner.resource_path.is_empty() and not _inner_names.has(inner):
				var full_name: String = "%s.%s" % [prefix, str(key)]
				_inner_names[inner] = full_name
				_index_inner_classes(inner, full_name, depth + 1)
