extends Node2D

const PLAYER_SCRIPT = preload("res://scripts/actors/player.gd")
const UNIT_SCRIPT = preload("res://scripts/actors/swarm_unit.gd")
const ENEMY_SCRIPT = preload("res://scripts/actors/chaser.gd")
const PROJECTILE_SCRIPT = preload("res://scripts/combat/projectile.gd")
const ORB_SCRIPT = preload("res://scripts/combat/energy_orb.gd")
const FX_SCRIPT = preload("res://scripts/fx/fx_layer.gd")

enum RunState { PLAYING, UPGRADING, PAUSED, ENDED }

@onready var enemy_layer: Node2D = $World/Enemies
@onready var projectile_layer: Node2D = $World/Projectiles
@onready var orb_layer: Node2D = $World/Orbs
@onready var unit_layer: Node2D = $World/Units
@onready var player_layer: Node2D = $World/PlayerLayer
@onready var effects_layer: Node2D = $World/Effects
@onready var hud: GameHUD = $UI

var player: SwarmPlayer
var fx: FxLayer
var enemies: Array = []
var projectiles: Array = []
var orbs: Array = []
var units: Array = []

var run_state := RunState.PLAYING
var previous_state := RunState.PLAYING
var elapsed := 0.0
var spawn_budget := 0.0
var score := 0
var best_score := 0
var kills := 0
var xp := 0
var xp_needed := GameConfig.FIRST_LEVEL_XP
var level := 0
var max_units := 2
var next_unit_id := 1
var last_hit_ago := 99.0
var orbit_phase := 0.0
var screen_shake := 0.0

var damage_multiplier := 1.0
var attack_interval := GameConfig.UNIT_ATTACK_INTERVAL
var projectile_speed_multiplier := 1.0
var mitosis_active := false
var mitosis_trigger_count := 0
var mitosis_next_kill := 0
var pulse_kills := 0
var acquired_rules: Array[String] = []
var formation := "ORBIT"


func _ready() -> void:
	randomize()
	player = PLAYER_SCRIPT.new()
	player_layer.add_child(player)
	fx = FX_SCRIPT.new()
	effects_layer.add_child(fx)
	prewarm_pools()
	hud.upgrade_chosen.connect(_on_upgrade_chosen)
	hud.restart_requested.connect(reset_run)
	load_best_score()
	reset_run()


func prewarm_pools() -> void:
	for index in range(GameConfig.ENEMY_POOL_SIZE):
		var enemy = ENEMY_SCRIPT.new()
		enemy.pool_id = index
		enemy_layer.add_child(enemy)
		enemy.deactivate()
		enemies.append(enemy)

	for index in range(GameConfig.PROJECTILE_POOL_SIZE):
		var projectile = PROJECTILE_SCRIPT.new()
		projectile_layer.add_child(projectile)
		projectile.deactivate()
		projectiles.append(projectile)

	for index in range(GameConfig.ORB_POOL_SIZE):
		var orb = ORB_SCRIPT.new()
		orb_layer.add_child(orb)
		orb.deactivate()
		orbs.append(orb)


func reset_run() -> void:
	for enemy in enemies:
		enemy.deactivate()
	for projectile in projectiles:
		projectile.deactivate()
	for orb in orbs:
		orb.deactivate()
	for unit in units:
		unit.visible = false
		unit.queue_free()
	units.clear()

	elapsed = 0.0
	spawn_budget = 0.0
	score = 0
	kills = 0
	xp = 0
	xp_needed = GameConfig.FIRST_LEVEL_XP
	level = 0
	max_units = 2
	next_unit_id = 1
	last_hit_ago = 99.0
	orbit_phase = 0.0
	screen_shake = 0.0
	damage_multiplier = 1.0
	attack_interval = GameConfig.UNIT_ATTACK_INTERVAL
	projectile_speed_multiplier = 1.0
	mitosis_active = false
	mitosis_trigger_count = 0
	mitosis_next_kill = 0
	pulse_kills = 0
	acquired_rules.clear()
	formation = "ORBIT"
	run_state = RunState.PLAYING
	position = Vector2.ZERO
	player.reset_player()
	fx.reset_fx()
	hud.hide_upgrade()
	hud.hide_result()
	hud.show_paused(false)
	add_unit(false)
	add_unit(false)
	update_hud()
	queue_redraw()


func _process(delta: float) -> void:
	fx.tick(delta)
	if run_state != RunState.PLAYING:
		queue_redraw()
		return

	elapsed += delta
	last_hit_ago += delta
	orbit_phase += delta * 0.45
	screen_shake = maxf(0.0, screen_shake - delta * 18.0)
	if screen_shake > 0.0:
		position = Vector2(randf_range(-screen_shake, screen_shake), randf_range(-screen_shake, screen_shake))
	else:
		position = Vector2.ZERO

	var blink_started := player.tick(delta)
	if blink_started:
		fx.burst(player.position, GameConfig.COLOR_CYAN, 36.0)

	update_spawning(delta)
	update_enemies(delta)
	update_units(delta)
	update_projectiles(delta)
	update_orbs(delta)

	if elapsed >= GameConfig.RUN_DURATION:
		end_run(true)
		return

	update_hud()
	queue_redraw()


func update_spawning(delta: float) -> void:
	if active_enemy_count() >= GameConfig.ENEMY_ACTIVE_MAX:
		return
	var rate := GameConfig.SPAWN_RATE_START * pow(GameConfig.SPAWN_GROWTH_PER_30, floorf(elapsed / 30.0))
	spawn_budget += delta * rate
	while spawn_budget >= 1.0 and active_enemy_count() < GameConfig.ENEMY_ACTIVE_MAX:
		spawn_budget -= 1.0
		spawn_enemy()


func spawn_enemy() -> void:
	var enemy = first_inactive(enemies)
	if enemy == null:
		return
	var side := randi() % 4
	var spawn_position := Vector2.ZERO
	match side:
		0:
			spawn_position = Vector2(randf_range(GameConfig.ARENA_RECT.position.x, GameConfig.ARENA_RECT.end.x), GameConfig.ARENA_RECT.position.y + 8.0)
		1:
			spawn_position = Vector2(GameConfig.ARENA_RECT.end.x - 8.0, randf_range(GameConfig.ARENA_RECT.position.y, GameConfig.ARENA_RECT.end.y))
		2:
			spawn_position = Vector2(randf_range(GameConfig.ARENA_RECT.position.x, GameConfig.ARENA_RECT.end.x), GameConfig.ARENA_RECT.end.y - 8.0)
		_:
			spawn_position = Vector2(GameConfig.ARENA_RECT.position.x + 8.0, randf_range(GameConfig.ARENA_RECT.position.y, GameConfig.ARENA_RECT.end.y))
	var minute_scale := 1.0 + maxf(0.0, elapsed - 120.0) / 60.0 * 0.18
	var speed_scale := 1.0 + elapsed / GameConfig.RUN_DURATION * 0.20
	enemy.activate(spawn_position, minute_scale, speed_scale)


func update_enemies(delta: float) -> void:
	for enemy in enemies:
		if not enemy.active:
			continue
		enemy.tick(delta, player.position)
		var hit_distance := GameConfig.ENEMY_RADIUS + GameConfig.PLAYER_RADIUS
		if enemy.contact_cooldown <= 0.0 and enemy.position.distance_squared_to(player.position) <= hit_distance * hit_distance:
			enemy.contact_cooldown = 0.55
			if player.take_hit():
				last_hit_ago = 0.0
				screen_shake = 6.0
				fx.burst(player.position, GameConfig.COLOR_RED, 48.0)
				enemy.position += player.position.direction_to(enemy.position) * 32.0
				if player.hp <= 0:
					end_run(false)
					return


func update_units(delta: float) -> void:
	var desired_formation := "DELTA" if units.size() >= 3 else "ORBIT"
	if desired_formation != formation:
		formation = desired_formation
		fx.formula(player.position + Vector2(-70, -76), "N≥3  →  DELTA", GameConfig.COLOR_YELLOW)
		screen_shake = 3.0

	for index in range(units.size()):
		var unit = units[index]
		unit.slot_index = index
		unit.tick_follow(delta, formation_target(index))
		if unit.attack_left <= 0.0:
			var target = nearest_enemy(unit.position)
			if target != null:
				var direction: Vector2 = unit.position.direction_to(target.position)
				spawn_projectile(unit.position, direction, unit.unit_id)
				unit.mark_attack(attack_interval)
			else:
				unit.attack_left = 0.08


func formation_target(index: int) -> Vector2:
	if formation == "ORBIT":
		var angle := orbit_phase + TAU * index / float(maxi(1, units.size()))
		return player.position + Vector2.from_angle(angle) * GameConfig.UNIT_ORBIT_RADIUS

	var row := 0
	var row_start := 0
	while index >= row_start + row + 1:
		row_start += row + 1
		row += 1
	var column := index - row_start
	var total_rows := 1
	while total_rows * (total_rows + 1) / 2 < units.size():
		total_rows += 1
	var spacing_x := 46.0
	var spacing_y := 39.0
	var local_target := Vector2((column - row * 0.5) * spacing_x, (row - (total_rows - 1) * 0.5) * spacing_y)
	var facing_rotation := player.last_direction.angle() + PI / 2.0
	return player.position + local_target.rotated(facing_rotation)


func spawn_projectile(at: Vector2, direction: Vector2, source_unit_id: int) -> void:
	var projectile = first_inactive(projectiles)
	if projectile == null:
		return
	var pierce := 1 if formation == "DELTA" else 0
	projectile.activate(at, direction, GameConfig.UNIT_DAMAGE * damage_multiplier, pierce, source_unit_id, projectile_speed_multiplier)


func update_projectiles(delta: float) -> void:
	for projectile in projectiles:
		if not projectile.active:
			continue
		projectile.tick(delta)
		if not projectile.active:
			continue
		for enemy in enemies:
			if not enemy.active:
				continue
			var hit_distance := GameConfig.PROJECTILE_RADIUS + GameConfig.ENEMY_RADIUS
			if projectile.position.distance_squared_to(enemy.position) > hit_distance * hit_distance:
				continue
			if not projectile.register_hit(enemy.pool_id):
				continue
			var killed: bool = enemy.take_damage(projectile.damage)
			fx.burst(projectile.position, GameConfig.COLOR_CYAN, 12.0)
			if killed:
				kill_enemy(enemy, projectile.source_unit_id)
			if not projectile.active:
				break


func kill_enemy(enemy, source_unit_id: int) -> void:
	var death_position: Vector2 = enemy.position
	enemy.deactivate()
	kills += 1
	pulse_kills += 1
	var stable_multiplier := 1.25 if last_hit_ago >= 5.0 else 1.0
	score += int(round(10.0 * current_risk() * stable_multiplier))
	fx.burst(death_position, GameConfig.COLOR_RED, 27.0)
	fx.shatter(death_position, GameConfig.COLOR_RED, randi_range(28, 38))
	if player.is_blink_window():
		fx.formula(death_position + Vector2(-42, -18), "CLOSE CALL", GameConfig.COLOR_YELLOW)
	spawn_orb(death_position)
	check_mitosis(source_unit_id)


func spawn_orb(at: Vector2) -> void:
	var orb = first_inactive(orbs)
	if orb != null:
		orb.activate(at)


func update_orbs(delta: float) -> void:
	for orb in orbs:
		if orb.active and orb.tick(delta, player.position):
			gain_xp(orb.value)


func gain_xp(amount: int) -> void:
	xp += amount
	if xp >= xp_needed and level < GameConfig.MAX_LEVEL_CHOICES:
		xp -= xp_needed
		level += 1
		xp_needed = GameConfig.FIRST_LEVEL_XP + level * GameConfig.XP_GROWTH
		show_upgrade()


func show_upgrade() -> void:
	run_state = RunState.UPGRADING
	hud.show_upgrade(build_upgrade_options(), level)


func build_upgrade_options() -> Array:
	var mitosis := {
		"id": "mitosis", "name": "MITOSIS", "formula": "●  →  ●●",
		"description": "PULSE 8킬마다 1기 복제 · 최대 5회",
		"forecast": "예상 변화  +5 UNITS"
	}
	var accelerate := {
		"id": "accelerate", "name": "ACCELERATE", "formula": "INTERVAL  ×  0.85",
		"description": "모든 PULSE 공격 주기 15% 감소",
		"forecast": "현재 %.2fs  →  %.2fs" % [attack_interval, attack_interval * 0.85]
	}
	var amplify := {
		"id": "amplify", "name": "AMPLIFY", "formula": "DMG  ×  1.25",
		"description": "모든 PULSE 피해 25% 증가",
		"forecast": "현재 %.1f  →  %.1f" % [GameConfig.UNIT_DAMAGE * damage_multiplier, GameConfig.UNIT_DAMAGE * damage_multiplier * 1.25]
	}
	if level == 1 and not mitosis_active:
		return [mitosis, accelerate, amplify]

	var pool: Array = [accelerate, amplify, {
		"id": "binary", "name": "BINARY", "formula": "N  +  1",
		"description": "PULSE 1기를 즉시 편대에 추가",
		"forecast": "현재 %d  →  %d UNITS" % [units.size(), mini(GameConfig.UNIT_MAX, units.size() + 1)]
	}, {
		"id": "vectoring", "name": "VECTORING", "formula": "SPEED  ×  1.20",
		"description": "탄환 속도 20% 증가",
		"forecast": "명중까지 걸리는 시간 감소"
	}, {
		"id": "repair", "name": "REPAIR", "formula": "HP  +  1",
		"description": "CORE 체력을 1 회복",
		"forecast": "현재 %d  →  %d CORE" % [player.hp, mini(GameConfig.PLAYER_MAX_HP, player.hp + 1)]
	}]
	if not mitosis_active:
		pool.append(mitosis)
	pool.shuffle()
	return pool.slice(0, 3)


func _on_upgrade_chosen(upgrade_id: String) -> void:
	if run_state != RunState.UPGRADING:
		return
	match upgrade_id:
		"mitosis":
			mitosis_active = true
			mitosis_next_kill = pulse_kills + 8
			acquired_rules.append("MITOSIS")
			fx.formula(player.position + Vector2(-48, -62), "●  →  ●●")
		"accelerate":
			attack_interval *= 0.85
			acquired_rules.append("×0.85")
			fx.formula(player.position + Vector2(-60, -62), "INTERVAL × 0.85")
		"amplify":
			damage_multiplier *= 1.25
			acquired_rules.append("DMG×1.25")
			fx.formula(player.position + Vector2(-55, -62), "DMG × 1.25")
		"binary":
			add_unit(true)
			acquired_rules.append("N+1")
		"vectoring":
			projectile_speed_multiplier *= 1.20
			acquired_rules.append("SPEED×1.20")
			fx.formula(player.position + Vector2(-55, -62), "SPEED × 1.20")
		"repair":
			player.hp = mini(GameConfig.PLAYER_MAX_HP, player.hp + 1)
			acquired_rules.append("HP+1")
			fx.formula(player.position + Vector2(-35, -62), "HP + 1", GameConfig.COLOR_YELLOW)
	hud.hide_upgrade()
	run_state = RunState.PLAYING
	update_hud()


func check_mitosis(_source_unit_id: int) -> void:
	if not mitosis_active or mitosis_trigger_count >= 5:
		return
	while pulse_kills >= mitosis_next_kill and mitosis_trigger_count < 5:
		mitosis_trigger_count += 1
		mitosis_next_kill += 8
		if add_unit(true):
			fx.formula(player.position + Vector2(-48, -70), "●  →  ●●")
		else:
			damage_multiplier *= 1.03
			fx.formula(player.position + Vector2(-50, -70), "30+  →  DMG")


func add_unit(with_effect: bool) -> bool:
	if units.size() >= GameConfig.UNIT_MAX:
		return false
	var unit = UNIT_SCRIPT.new()
	unit_layer.add_child(unit)
	unit.setup(next_unit_id, player.position + Vector2(randf_range(-18, 18), randf_range(-18, 18)))
	next_unit_id += 1
	units.append(unit)
	max_units = maxi(max_units, units.size())
	if with_effect:
		fx.burst(player.position, GameConfig.COLOR_CYAN, 52.0)
	return true


func nearest_enemy(from: Vector2):
	var nearest = null
	var best_distance_sq := GameConfig.UNIT_RANGE * GameConfig.UNIT_RANGE
	for enemy in enemies:
		if not enemy.active:
			continue
		var distance_sq: float = from.distance_squared_to(enemy.position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearest = enemy
	return nearest


func first_inactive(pool: Array):
	for item in pool:
		if not item.active:
			return item
	return null


func active_enemy_count() -> int:
	var count := 0
	for enemy in enemies:
		if enemy.active:
			count += 1
	return count


func active_projectile_count() -> int:
	var count := 0
	for projectile in projectiles:
		if projectile.active:
			count += 1
	return count


func current_risk() -> float:
	return 1.0 + floorf(elapsed / 30.0) * 0.25


func current_formula() -> String:
	var parts: Array[String] = ["%d PULSE" % units.size(), formation]
	if mitosis_active:
		parts.append("MITOSIS")
	for rule in acquired_rules:
		if rule != "MITOSIS" and not parts.has(rule):
			parts.append(rule)
	return " × ".join(parts)


func update_hud() -> void:
	hud.update_hud({
		"hp": player.hp,
		"max_hp": GameConfig.PLAYER_MAX_HP,
		"remaining": maxf(0.0, GameConfig.RUN_DURATION - elapsed),
		"elapsed": elapsed,
		"score": score,
		"risk": current_risk(),
		"formation": formation + ("  //  PIERCE +1" if formation == "DELTA" else ""),
		"formula": current_formula(),
		"enemies": active_enemy_count(),
		"units": units.size(),
		"projectiles": active_projectile_count(),
		"xp": xp,
		"xp_needed": xp_needed,
		"blink": player.blink_charge()
	})


func end_run(won: bool) -> void:
	if run_state == RunState.ENDED:
		return
	run_state = RunState.ENDED
	var final_score := score + (player.hp * 500 if won else 0)
	best_score = maxi(best_score, final_score)
	save_best_score()
	var survived := minf(elapsed, GameConfig.RUN_DURATION)
	var minutes := int(survived) / 60
	var seconds := int(survived) % 60
	hud.show_result(won, {
		"score": final_score,
		"best": best_score,
		"survival": "%02d:%02d" % [minutes, seconds],
		"kills": kills,
		"max_units": max_units,
		"mitosis_count": mitosis_trigger_count,
		"formula": current_formula()
	})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if run_state == RunState.PLAYING:
			previous_state = run_state
			run_state = RunState.PAUSED
			hud.show_paused(true)
		elif run_state == RunState.PAUSED:
			run_state = previous_state
			hud.show_paused(false)
		get_viewport().set_input_as_handled()
		return

	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if run_state == RunState.UPGRADING:
		match event.keycode:
			KEY_1: hud.choose_card(0)
			KEY_2: hud.choose_card(1)
			KEY_3: hud.choose_card(2)
	elif run_state == RunState.ENDED and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_R]:
		reset_run()


func load_best_score() -> void:
	var config := ConfigFile.new()
	if config.load("user://frctl_swarm.cfg") == OK:
		best_score = int(config.get_value("score", "best", 0))


func save_best_score() -> void:
	var config := ConfigFile.new()
	config.set_value("score", "best", best_score)
	config.save("user://frctl_swarm.cfg")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, GameConfig.VIEW_SIZE), GameConfig.COLOR_BG)
	var rect := GameConfig.ARENA_RECT
	for x in range(int(rect.position.x), int(rect.end.x) + 1, 40):
		var color := GameConfig.COLOR_GRID_MAJOR if (x - int(rect.position.x)) % 200 == 0 else GameConfig.COLOR_GRID
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(color, 0.30), 1.0)
	for y in range(int(rect.position.y), int(rect.end.y) + 1, 40):
		var color := GameConfig.COLOR_GRID_MAJOR if (y - int(rect.position.y)) % 200 == 0 else GameConfig.COLOR_GRID
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(color, 0.30), 1.0)
	draw_rect(rect, Color(GameConfig.COLOR_CYAN_DIM, 0.55), false, 2.0)
	draw_line(Vector2(rect.position.x, rect.position.y + 18), Vector2(rect.position.x, rect.position.y), GameConfig.COLOR_CYAN, 2.0)
	draw_line(Vector2(rect.position.x, rect.position.y), Vector2(rect.position.x + 18, rect.position.y), GameConfig.COLOR_CYAN, 2.0)
	draw_line(Vector2(rect.end.x - 18, rect.end.y), rect.end, GameConfig.COLOR_CYAN, 2.0)
	draw_line(rect.end, Vector2(rect.end.x, rect.end.y - 18), GameConfig.COLOR_CYAN, 2.0)

	if units.is_empty():
		return
	for unit in units:
		draw_line(player.position, unit.position, Color(GameConfig.COLOR_CYAN_DIM, 0.12), 1.0, true)
	if formation == "DELTA" and units.size() >= 3:
		var outline := PackedVector2Array([units[0].position, units[1].position, units[2].position, units[0].position])
		draw_polyline(outline, Color(GameConfig.COLOR_CYAN, 0.38), 2.0, true)
