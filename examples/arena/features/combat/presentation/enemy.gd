class_name ArenaEnemy
extends CharacterBody2D
## An enemy driven by a TrStateMachine: Alive (Wander, Chase) and Dead.

var target: Node2D
var health: Health
var config: CombatConfig
var bus: TrEventBus
var flash: float = 0.0

@onready var machine: TrStateMachine = $StateMachine


func _inject(c: TrServiceContainer) -> void:
	config = c.get_service(CombatConfig) as CombatConfig
	bus = c.get_service(TrEventBus) as TrEventBus
	health = Health.new(config.enemy_health)


func _ready() -> void:
	add_to_group(&"enemies")


func is_alive() -> bool:
	return health != null and not health.is_dead()


func hit(amount: int) -> void:
	var result: TrResult = health.damage(amount)
	if result.is_err():
		return
	flash = 0.08
	if health.is_dead():
		machine.transition_to(EnemyDead)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var color := Color(1.0, 0.3, 0.3) if flash <= 0.0 else Color.WHITE
	if not is_alive():
		color = Color(0.4, 0.4, 0.4)
	draw_circle(Vector2.ZERO, 10.0, color)
