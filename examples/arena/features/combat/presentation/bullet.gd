class_name ArenaBullet
extends Area2D
## A projectile built in code. Hits ArenaEnemy bodies on collision layer 2.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 600.0
var damage: int = 1
var _life: float = 1.2


func _init() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	var enemy := body as ArenaEnemy
	if enemy != null and enemy.is_alive():
		enemy.hit(damage)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.95, 0.4))
