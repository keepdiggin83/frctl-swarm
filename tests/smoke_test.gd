extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame

	assert(game.units.size() == 2, "Run must begin with two PULSE units")
	assert(game.formation == "ORBIT", "Two units must begin in ORBIT formation")
	assert(game.player.hp == GameConfig.PLAYER_MAX_HP, "Player HP did not initialize")
	assert(GameConfig.MAP_SIZE == GameConfig.VIEW_SIZE * 3.0, "Map must cover a 3x3 screen grid")
	assert(game.current_sector() == "2:2", "Player must start in the center sector")

	var start_position: Vector2 = game.player.position
	Input.action_press("move_right")
	game.player.tick(3.0)
	Input.action_release("move_right")
	assert(game.player.position.x - start_position.x > GameConfig.VIEW_SIZE.x * 0.5, "Player could not travel beyond the original screen")

	var spawn_test_positions := [
		GameConfig.MAP_RECT.get_center(),
		GameConfig.MAP_RECT.position + Vector2(18.0, 18.0),
		Vector2(GameConfig.MAP_RECT.end.x - 18.0, GameConfig.MAP_RECT.position.y + 18.0),
		Vector2(GameConfig.MAP_RECT.position.x + 18.0, GameConfig.MAP_RECT.end.y - 18.0),
		GameConfig.MAP_RECT.end - Vector2(18.0, 18.0)
	]
	for test_position in spawn_test_positions:
		game.player.position = test_position
		for iteration in range(12):
			game.spawn_enemy()
			var offscreen_enemy = null
			for candidate in game.enemies:
				if candidate.active:
					offscreen_enemy = candidate
					break
			assert(offscreen_enemy != null, "Enemy spawn did not activate")
			assert(GameConfig.MAP_RECT.has_point(offscreen_enemy.position), "Enemy spawned outside the map")
			assert(not game.camera_world_rect().grow(GameConfig.ENEMY_RADIUS).has_point(offscreen_enemy.position), "Enemy must spawn fully outside the camera view")
			offscreen_enemy.deactivate()
	game.player.position = GameConfig.MAP_RECT.get_center()

	Input.action_press("blink")
	var blink_started: bool = game.player.tick(0.016)
	Input.action_release("blink")
	assert(blink_started, "Blink did not activate")
	assert(game.player.blink_cooldown_left > 0.0, "Blink cooldown did not start")

	game.mitosis_active = true
	game.mitosis_next_kill = 8
	game.pulse_kills = 8
	game.check_mitosis(1)
	game.update_units(0.016)
	assert(game.units.size() == 3, "MITOSIS did not create a PULSE unit")
	assert(game.formation == "DELTA", "Three units did not switch to DELTA formation")

	var enemy = game.first_inactive(game.enemies)
	enemy.activate(game.player.position + Vector2(120, 0), 1.0, 1.0)
	enemy.hp = 5.0
	game.spawn_projectile(enemy.position, Vector2.RIGHT, game.units[0].unit_id)
	var projectile = null
	for candidate in game.projectiles:
		if candidate.active:
			projectile = candidate
			break
	assert(projectile != null, "Projectile pool did not activate a projectile")
	projectile.position = enemy.position
	game.update_projectiles(0.0)
	assert(not enemy.active, "Projectile hit did not kill the enemy")
	assert(game.kills == 1, "Kill event did not update the counter")

	var first_options: Array = game.build_upgrade_options()
	assert(first_options.size() == 3, "Upgrade screen must offer three choices")

	print("SMOKE_TEST_OK: 3x3 map, offscreen spawning, movement, blink, combat, MITOSIS, DELTA, and upgrades")
	quit(0)
