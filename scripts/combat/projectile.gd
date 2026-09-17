class_name PulseProjectile
extends Node2D

var active := false
var velocity := Vector2.ZERO
var damage := 0.0
var life_left := 0.0
var pierce_left := 0
var source_unit_id := 0
var hit_enemy_ids := {}


func activate(new_position: Vector2, direction: Vector2, new_damage: float, new_pierce: int, source_id: int, speed_scale: float) -> void:
	position = new_position
	velocity = direction.normalized() * GameConfig.PROJECTILE_SPEED * speed_scale
	damage = new_damage
	life_left = 1.25
	pierce_left = new_pierce
	source_unit_id = source_id
	hit_enemy_ids.clear()
	active = true
	visible = true
	rotation = velocity.angle()
	queue_redraw()


func deactivate() -> void:
	active = false
	visible = false
	hit_enemy_ids.clear()


func tick(delta: float) -> void:
	if not active:
		return
	position += velocity * delta
	life_left -= delta
	if life_left <= 0.0 or not GameConfig.ARENA_RECT.grow(80.0).has_point(position):
		deactivate()


func register_hit(enemy_id: int) -> bool:
	if hit_enemy_ids.has(enemy_id):
		return false
	hit_enemy_ids[enemy_id] = true
	if pierce_left > 0:
		pierce_left -= 1
	else:
		deactivate()
	return true


func _draw() -> void:
	draw_line(Vector2(-12.0, 0.0), Vector2(5.0, 0.0), Color(0.32, 0.96, 0.82, 0.25), 7.0, true)
	draw_line(Vector2(-8.0, 0.0), Vector2(6.0, 0.0), GameConfig.COLOR_WHITE, 2.5, true)
	draw_circle(Vector2(6.0, 0.0), GameConfig.PROJECTILE_RADIUS, GameConfig.COLOR_CYAN)

