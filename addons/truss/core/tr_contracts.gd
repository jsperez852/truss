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


## A readable name for a script: its [code]class_name[/code], or its path when it has none.
static func describe(script: Script) -> String:
	if script == null:
		return "<null script>"
	var global_name: StringName = script.get_global_name()
	if global_name != &"":
		return String(global_name)
	return script.resource_path if not script.resource_path.is_empty() else "<anonymous script>"


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
