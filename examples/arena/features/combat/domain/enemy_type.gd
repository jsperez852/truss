class_name EnemyType
extends Resource
## Domain: an enemy variant, authored as a .tres in features/combat/data/enemies/.

@export var id: StringName
@export var health: int = 2
@export var speed: float = 80.0
@export var color: Color = Color(1.0, 0.3, 0.3)
@export var points: int = 10
## Relative chance of appearing in a wave.
@export var weight: float = 1.0
