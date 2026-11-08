class_name TrModifierDef
extends Resource
## A modifier authored in the inspector, for items, upgrades and effects saved as .tres files.
##
## [codeblock]
## # res://data/items/iron_sword.tres -> ItemDef with
## #   @export var modifiers: Array[TrModifierDef]   (damage FLAT 5, attack_speed PERCENT 0.1)
## TrModifierDef.apply_all(item.modifiers, player_stats, item)   # equip
## player_stats.remove_from(item)                                # unequip
## [/codeblock]

## The stat to modify (must be declared in the target [TrStats]).
@export var stat: StringName
@export var kind: TrModifier.Kind = TrModifier.Kind.FLAT
## Flat amount, fraction for PERCENT (0.1 = +10 %), or factor for MULTIPLY.
@export var amount: float = 0.0


## A [TrModifier] from this definition, tagged with [param source].
func create(source: Variant = null) -> TrModifier:
	return TrModifier.new(kind, amount, source)


## Adds this modifier to [param stats]. Returns it, or [code]null[/code] when [member stat] isn't declared
## (that is reported as an error by [TrStats]).
func apply_to(stats: TrStats, source: Variant = null) -> TrModifier:
	return stats.add(stat, create(source))


## Applies every definition in [param defs] with the same [param source]. Returns how many were applied.
static func apply_all(defs: Array[TrModifierDef], stats: TrStats, source: Variant = null) -> int:
	var applied: int = 0
	for def: TrModifierDef in defs:
		if def != null and def.apply_to(stats, source) != null:
			applied += 1
	return applied
