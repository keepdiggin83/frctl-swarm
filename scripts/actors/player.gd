class_name SwarmPlayer
extends Node2D

var hp := GameConfig.PLAYER_MAX_HP
var last_direction := Vector2.UP
var invulnerable_left := 0.0
var blink_cooldown_left := 0.0
var blink_left := 0.0
var blink_direction := Vector2.UP
var blink_started_at := -10.0
var elapsed_time := 0.0
var trail: Array[Vector2] = []


func reset_player() -> void:
	hp = GameConfig.PLAYER_MAX_HP
	position = GameConfig.MAP_RECT.get_center()
	last_direction = Vector2.UP
	invulnerable_left = 0.0
	blink_cooldown_left = 0.0
	blink_left = 0.0
	blink_started_at = -10.0
	elapsed_time = 0.0
	trail.clear()
	visible = true
	queue_redraw()


func tick(delta: float) -> bool:
	elapsed_time += delta
	invulnerable_left = maxf(0.0, invulnerable_left - delta)
	blink_cooldown_left = maxf(0.0, blink_cooldown_left - delta)

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length_squared() > 0.01:
		last_direction = input_vector.normalized()

	var started_blink := false
	if Input.is_action_just_pressed("blink") and blink_cooldown_left <= 0.0:
		blink_direction = last_direction
		blink_left = GameConfig.BLINK_DURATION
		blink_cooldown_left = GameConfig.BLINK_COOLDOWN
		blink_started_at = elapsed_time
		started_blink = true

	if blink_left > 0.0:
		trail.push_front(position)
		if trail.size() > 7:
			trail.pop_back()
		position += blink_direction * (GameConfig.BLINK_DISTANCE / GameConfig.BLINK_DURATION) * delta
		blink_left = maxf(0.0, blink_left - delta)
	else:
		position += input_vector * GameConfig.PLAYER_SPEED * delta
		if not trail.is_empty():
			trail.pop_back()

	position.x = clampf(position.x, GameConfig.MAP_RECT.position.x + 18.0, GameConfig.MAP_RECT.end.x - 18.0)
	position.y = clampf(position.y, GameConfig.MAP_RECT.position.y + 18.0, GameConfig.MAP_RECT.end.y - 18.0)
	queue_redraw()
	return started_blink


func take_hit() -> bool:
	if invulnerable_left > 0.0 or blink_left > 0.0:
		return false
	hp -= 1
	invulnerable_left = GameConfig.PLAYER_IFRAME
	queue_redraw()
	return true


func is_blink_window() -> bool:
	return elapsed_time - blink_started_at <= 0.4


func blink_charge() -> float:
	return 1.0 - (blink_cooldown_left / GameConfig.BLINK_COOLDOWN)


func _draw() -> void:
	for index in range(trail.size() - 1, -1, -1):
		var alpha := (trail.size() - index) / float(maxi(1, trail.size())) * 0.26
		var local_pos := trail[index] - position
		draw_circle(local_pos, GameConfig.PLAYER_RADIUS * 0.75, Color(0.32, 0.96, 0.82, alpha))

	var flicker := invulnerable_left > 0.0 and int(elapsed_time * 18.0) % 2 == 0
	var core_color := Color(GameConfig.COLOR_WHITE, 0.35) if flicker else GameConfig.COLOR_WHITE
	draw_circle(Vector2.ZERO, GameConfig.PLAYER_RADIUS + 7.0, Color(0.32, 0.96, 0.82, 0.10))
	draw_arc(Vector2.ZERO, GameConfig.PLAYER_RADIUS + 5.0, 0.0, TAU, 40, GameConfig.COLOR_CYAN_DIM, 2.0)
	draw_circle(Vector2.ZERO, GameConfig.PLAYER_RADIUS, core_color)
	draw_circle(Vector2.ZERO, 5.0, GameConfig.COLOR_BG)
	draw_line(Vector2.ZERO, last_direction * 11.0, GameConfig.COLOR_CYAN, 3.0, true)

	var start_angle := -PI / 2.0
	draw_arc(Vector2.ZERO, 27.0, start_angle, start_angle + TAU * blink_charge(), 42, GameConfig.COLOR_CYAN, 3.0, true)
