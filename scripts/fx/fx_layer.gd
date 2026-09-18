class_name FxLayer
extends Node2D

var bursts: Array = []
var floaters: Array = []
var debris: Array = []
var edge_pulse := 0.0
const MAX_DEBRIS := 900


func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


func reset_fx() -> void:
	bursts.clear()
	floaters.clear()
	debris.clear()
	edge_pulse = 0.0
	queue_redraw()


func burst(at: Vector2, color: Color, size := 18.0) -> void:
	bursts.append({"position": at, "color": color, "size": size, "life": 0.28, "max_life": 0.28})
	queue_redraw()


func formula(at: Vector2, value: String, color := GameConfig.COLOR_CYAN) -> void:
	floaters.append({"position": at, "text": value, "color": color, "life": 0.75, "max_life": 0.75})
	edge_pulse = 0.35
	queue_redraw()


func shatter(at: Vector2, color: Color, amount := 24) -> void:
	var phase := randf() * TAU
	for index in range(amount):
		var angle := phase + TAU * index / float(amount) + randf_range(-0.24, 0.24)
		var direction := Vector2.from_angle(angle)
		var speed := randf_range(95.0, 340.0) * (1.25 if index % 5 == 0 else 1.0)
		var lifetime := randf_range(0.38, 0.82)
		var start := at + direction * randf_range(0.0, 6.0)
		debris.append({
			"position": start,
			"previous": start,
			"velocity": direction * speed + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 28.0),
			"color": color,
			"life": lifetime,
			"max_life": lifetime,
			"size": randf_range(1.5, 4.2),
			"rotation": randf() * TAU,
			"spin": randf_range(-13.0, 13.0),
			"shape": randi() % 3
		})
	if debris.size() > MAX_DEBRIS:
		debris = debris.slice(debris.size() - MAX_DEBRIS)
	edge_pulse = maxf(edge_pulse, 0.18)
	queue_redraw()


func tick(delta: float) -> void:
	edge_pulse = maxf(0.0, edge_pulse - delta)
	for item in bursts:
		item.life -= delta
	for item in floaters:
		item.life -= delta
		item.position.y -= 34.0 * delta
	for item in debris:
		item.life -= delta
		item.previous = item.position
		item.position += item.velocity * delta
		item.velocity *= exp(-2.8 * delta)
		item.rotation += item.spin * delta
	bursts = bursts.filter(func(item): return item.life > 0.0)
	floaters = floaters.filter(func(item): return item.life > 0.0)
	debris = debris.filter(func(item): return item.life > 0.0)
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

	for item in debris:
		var alpha: float = clampf(item.life / item.max_life, 0.0, 1.0)
		var speed: float = item.velocity.length()
		var direction: Vector2 = item.velocity.normalized() if speed > 0.01 else Vector2.RIGHT
		var trail: float = clampf(speed * 0.035, 4.0, 16.0)
		var glow := item.color as Color
		glow.a = alpha * 0.18
		var core: Color = (item.color as Color).lerp(GameConfig.COLOR_WHITE, 0.55)
		core.a = alpha * 0.92
		draw_line(item.position - direction * trail, item.position, glow, item.size * 3.4, true)
		draw_line(item.position - direction * trail * 0.72, item.position, core, maxf(1.0, item.size * 0.55), true)

		if item.shape == 1:
			var axis: Vector2 = Vector2.from_angle(item.rotation) * item.size * 1.8
			var side: Vector2 = axis.rotated(2.25)
			var points := PackedVector2Array([item.position + axis, item.position + side, item.position - axis * 0.75, item.position + axis])
			draw_polyline(points, core, 1.0, true)
		elif item.shape == 2:
			var axis: Vector2 = Vector2.from_angle(item.rotation) * item.size * 1.4
			draw_line(item.position - axis, item.position + axis, core, 1.0, true)
			draw_line(item.position - axis.rotated(PI / 2.0), item.position + axis.rotated(PI / 2.0), core, 1.0, true)

	var font := ThemeDB.fallback_font
	for item in floaters:
		var alpha: float = clampf(item.life / item.max_life, 0.0, 1.0)
		var color: Color = item.color
		color.a = alpha
		draw_string(font, item.position, item.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, 18, color)

	if edge_pulse > 0.0:
		var color := Color(GameConfig.COLOR_CYAN, edge_pulse * 0.28)
		draw_rect(Rect2(Vector2.ZERO, GameConfig.VIEW_SIZE), color, false, 5.0)
