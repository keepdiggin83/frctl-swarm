class_name ChaserEnemy
extends Node2D

var active := false
var pool_id := 0
var hp := GameConfig.ENEMY_HP
var max_hp := GameConfig.ENEMY_HP
var speed := GameConfig.ENEMY_SPEED
var hit_flash := 0.0
var contact_cooldown := 0.0
var wobble := 0.0


func activate(new_position: Vector2, health_scale: float, speed_scale: float) -> void:
	position = new_position
	max_hp = GameConfig.ENEMY_HP * health_scale
	hp = max_hp
	speed = GameConfig.ENEMY_SPEED * speed_scale
	hit_flash = 0.0
	contact_cooldown = 0.0
	wobble = randf() * TAU
	active = true
	visible = true
	queue_redraw()


func deactivate() -> void:
	active = false
	visible = false


func tick(delta: float, target: Vector2) -> void:
	if not active:
		return
	hit_flash = maxf(0.0, hit_flash - delta)
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	wobble += delta * 3.0
	var direction := position.direction_to(target)
	var tangent := Vector2(-direction.y, direction.x) * sin(wobble) * 0.08
	position += (direction + tangent).normalized() * speed * delta
	queue_redraw()


func take_damage(amount: float) -> bool:
	hp -= amount
	hit_flash = 0.07
	queue_redraw()
	return hp <= 0.0


func _draw() -> void:
	if not active:
		return
	var color := GameConfig.COLOR_WHITE if hit_flash > 0.0 else GameConfig.COLOR_RED
	var points := PackedVector2Array([
		Vector2(0.0, -GameConfig.ENEMY_RADIUS),
		Vector2(GameConfig.ENEMY_RADIUS, 0.0),
		Vector2(0.0, GameConfig.ENEMY_RADIUS),
		Vector2(-GameConfig.ENEMY_RADIUS, 0.0)
	])
	draw_colored_polygon(points, Color(GameConfig.COLOR_RED, 0.18))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), color, 2.5, true)
	draw_circle(Vector2.ZERO, 3.0, color)
	if hp < max_hp:
		draw_rect(Rect2(-13.0, -20.0, 26.0, 3.0), GameConfig.COLOR_RED_DIM)
		draw_rect(Rect2(-13.0, -20.0, 26.0 * maxf(0.0, hp / max_hp), 3.0), GameConfig.COLOR_RED)

