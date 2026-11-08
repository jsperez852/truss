class_name ArenaPlayer
extends CharacterBody2D
## Moves with WASD (or a bot in autoplay) and fires at the nearest enemy.

const CENTER: Vector2 = Vector2(480, 270)

var _config: CombatConfig
var _options: GameOptions
var _cooldown: float = 0.0
var _time: float = 0.0


func _inject(c: TrServiceContainer) -> void:
	_config = c.get_service(CombatConfig) as CombatConfig
	_options = c.get_service(GameOptions) as GameOptions


func _physics_process(delta: float) -> void:
	if _config == null:
		return
	_time += delta
	var direction: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if _options.autoplay:
		var waypoint: Vector2 = CENTER + Vector2(cos(_time), sin(_time)) * 140.0
		direction = global_position.direction_to(waypoint)
	velocity = direction * _config.player_speed
	move_and_slide()
	_cooldown -= delta
	if _cooldown <= 0.0:
		var target: ArenaEnemy = _nearest_enemy()
		if target != null:
			_fire(global_position.direction_to(target.global_position))
			_cooldown = _config.fire_interval
	queue_redraw()


func _nearest_enemy() -> ArenaEnemy:
	var best: ArenaEnemy = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as ArenaEnemy
		var distance: float = global_position.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best


func _fire(direction: Vector2) -> void:
	var bullet := ArenaBullet.new()
	bullet.direction = direction
	bullet.speed = _config.bullet_speed
	bullet.damage = _config.bullet_damage
	bullet.global_position = global_position
	get_parent().add_child(bullet)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color(0.35, 0.75, 1.0))
