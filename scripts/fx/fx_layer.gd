class_name FxLayer
extends Node2D

var bursts: Array = []
var floaters: Array = []
var edge_pulse := 0.0


func reset_fx() -> void:
	bursts.clear()
	floaters.clear()
	edge_pulse = 0.0
	queue_redraw()


func burst(at: Vector2, color: Color, size := 18.0) -> void:
	bursts.append({"position": at, "color": color, "size": size, "life": 0.28, "max_life": 0.28})
	queue_redraw()


func formula(at: Vector2, value: String, color := GameConfig.COLOR_CYAN) -> void:
	floaters.append({"position": at, "text": value, "color": color, "life": 0.75, "max_life": 0.75})
	edge_pulse = 0.35
	queue_redraw()


func tick(delta: float) -> void:
	edge_pulse = maxf(0.0, edge_pulse - delta)
	for item in bursts:
		item.life -= delta
	for item in floaters:
		item.life -= delta
		item.position.y -= 34.0 * delta
	bursts = bursts.filter(func(item): return item.life > 0.0)
	floaters = floaters.filter(func(item): return item.life > 0.0)
	queue_redraw()


func _draw() -> void:
	for item in bursts:
		var progress: float = 1.0 - item.life / item.max_life
		var alpha: float = 1.0 - progress
		var radius: float = lerpf(3.0, item.size, progress)
		var color: Color = item.color
		color.a = alpha * 0.75
		draw_arc(item.position, radius, 0.0, TAU, 22, color, 2.0, true)
		for index in range(4):
			var direction := Vector2.from_angle(index * PI / 2.0 + 0.35)
			draw_line(item.position + direction * radius * 0.4, item.position + direction * radius, color, 1.5, true)

	var font := ThemeDB.fallback_font
	for item in floaters:
		var alpha: float = clampf(item.life / item.max_life, 0.0, 1.0)
		var color: Color = item.color
		color.a = alpha
		draw_string(font, item.position, item.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, 18, color)

	if edge_pulse > 0.0:
		var color := Color(GameConfig.COLOR_CYAN, edge_pulse * 0.28)
		draw_rect(Rect2(Vector2.ZERO, GameConfig.VIEW_SIZE), color, false, 5.0)

