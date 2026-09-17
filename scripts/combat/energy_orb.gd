class_name EnergyOrb
extends Node2D

var active := false
var value := 1
var phase := 0.0


func activate(new_position: Vector2) -> void:
	position = new_position
	phase = randf() * TAU
	active = true
	visible = true
	queue_redraw()


func deactivate() -> void:
	active = false
	visible = false


func tick(delta: float, player_position: Vector2) -> bool:
	if not active:
		return false
	phase += delta * 5.0
	var distance := position.distance_to(player_position)
	if distance <= GameConfig.ORB_ATTRACT_RANGE:
		var strength := lerpf(0.35, 1.0, 1.0 - distance / GameConfig.ORB_ATTRACT_RANGE)
		position = position.move_toward(player_position, GameConfig.ORB_SPEED * strength * delta)
	if position.distance_to(player_position) <= GameConfig.ORB_COLLECT_RANGE:
		deactivate()
		return true
	queue_redraw()
	return false


func _draw() -> void:
	var radius := 3.5 + sin(phase) * 0.7
	draw_circle(Vector2.ZERO, radius + 4.0, Color(1.0, 0.82, 0.4, 0.13))
	draw_circle(Vector2.ZERO, radius, GameConfig.COLOR_YELLOW)

