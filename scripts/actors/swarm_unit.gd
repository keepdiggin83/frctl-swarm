class_name SwarmUnit
extends Node2D

var unit_id := 0
var slot_index := 0
var attack_left := 0.0
var pulse_phase := 0.0
var attack_flash := 0.0


func setup(new_id: int, start_position: Vector2) -> void:
	unit_id = new_id
	position = start_position
	attack_left = randf_range(0.08, GameConfig.UNIT_ATTACK_INTERVAL)
	pulse_phase = randf() * TAU
	visible = true
	queue_redraw()


func tick_follow(delta: float, target_position: Vector2) -> void:
	pulse_phase += delta * 2.2
	attack_left -= delta
	attack_flash = maxf(0.0, attack_flash - delta)
	position = position.lerp(target_position, 1.0 - exp(-GameConfig.UNIT_FOLLOW_SPEED * delta))
	queue_redraw()


func mark_attack(interval: float) -> void:
	attack_left += interval
	attack_flash = 0.09
	queue_redraw()


func _draw() -> void:
	var bob := sin(pulse_phase) * 0.8
	var radius := 9.0 + bob + (2.5 if attack_flash > 0.0 else 0.0)
	draw_circle(Vector2.ZERO, radius + 5.0, Color(0.32, 0.96, 0.82, 0.10))
	draw_circle(Vector2.ZERO, radius, GameConfig.COLOR_CYAN)
	draw_circle(Vector2.ZERO, radius - 4.0, GameConfig.COLOR_BG)
	draw_circle(Vector2.ZERO, 2.4, GameConfig.COLOR_WHITE)

