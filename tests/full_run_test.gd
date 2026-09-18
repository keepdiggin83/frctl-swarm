extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame

	var frames := 0
	var max_frames := int(GameConfig.RUN_DURATION * 60.0) + 120
	while game.run_state != 3 and frames < max_frames:
		# Keep this deterministic simulation focused on the combat loop rather than
		# player pathfinding. Enemies may touch the stationary core without damage.
		game.player.invulnerable_left = 1.0
		game._process(1.0 / 60.0)
		# A human would route through dropped energy. Move drops to the stationary
		# test core so upgrade progression is covered without pathfinding AI.
		for orb in game.orbs:
			if orb.active:
				orb.position = game.player.position
		if game.run_state == 1:
			game._on_upgrade_chosen("mitosis" if game.level == 1 else "accelerate")
		frames += 1

	if not _check(game.run_state == 3, "The accelerated three-minute run did not finish"): return
	if not _check(game.elapsed >= GameConfig.RUN_DURATION, "Run ended before the timer"): return
	if not _check(game.kills > 0, "Automated PULSE units recorded no kills"): return
	if not _check(game.mitosis_trigger_count == 5, "MITOSIS did not reach its five-trigger cap"): return
	if not _check(game.units.size() == 7, "Two initial units plus five MITOSIS units expected"): return
	if not _check(game.formation == "DELTA", "Final formation must be DELTA"): return
	if not _check(game.current_round == 6, "Three-minute run must reach round six"): return
	print("FULL_RUN_OK: round %d, %d kills, %d units, %d score, %.1f seconds" % [game.current_round, game.kills, game.units.size(), game.score, game.elapsed])
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("FULL_RUN_FAILED: " + message)
	quit(1)
	return false
