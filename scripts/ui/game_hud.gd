class_name GameHUD
extends CanvasLayer

signal upgrade_chosen(upgrade_id: String)
signal restart_requested

var health_label: Label
var timer_label: Label
var score_label: Label
var formation_label: Label
var map_label: Label
var rules_label: Label
var debug_label: Label
var xp_bar: ProgressBar
var xp_label: Label
var hint_label: Label
var status_label: Label

var upgrade_overlay: ColorRect
var upgrade_title: Label
var card_buttons: Array[Button] = []
var result_overlay: ColorRect
var result_title: Label
var result_stats: Label
var pause_overlay: ColorRect

var cyan_style: StyleBoxFlat
var panel_style: StyleBoxFlat


func _ready() -> void:
	_build_styles()
	_build_hud()
	_build_upgrade_overlay()
	_build_result_overlay()
	_build_pause_overlay()


func _build_styles() -> void:
	panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.055, 0.095, 0.90)
	panel_style.border_color = Color(0.20, 0.55, 0.58, 0.42)
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left = 7
	panel_style.corner_radius_top_right = 7
	panel_style.corner_radius_bottom_left = 7
	panel_style.corner_radius_bottom_right = 7
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_bottom = 10.0

	cyan_style = panel_style.duplicate()
	cyan_style.border_color = GameConfig.COLOR_CYAN
	cyan_style.set_border_width_all(2)
	cyan_style.bg_color = Color(0.03, 0.10, 0.13, 0.97)


func _base_control() -> Control:
	var control := Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(control)
	return control


func _label(text_value: String, size: int, color: Color = GameConfig.COLOR_WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _build_hud() -> void:
	var root := _base_control()

	health_label = _label("CORE  ◇ ◇ ◇ ◇ ◇", 19)
	health_label.position = Vector2(36, 21)
	health_label.size = Vector2(320, 36)
	root.add_child(health_label)

	timer_label = _label("03:00", 27, GameConfig.COLOR_WHITE)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.position = Vector2(550, 14)
	timer_label.size = Vector2(180, 46)
	root.add_child(timer_label)

	score_label = _label("SCORE  000000  //  RISK ×1.00", 17)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.position = Vector2(880, 22)
	score_label.size = Vector2(364, 34)
	root.add_child(score_label)

	formation_label = _label("FORMATION  //  ORBIT", 15, GameConfig.COLOR_CYAN)
	formation_label.position = Vector2(42, 88)
	formation_label.size = Vector2(310, 30)
	root.add_child(formation_label)

	map_label = _label("MAP 3×3  //  SECTOR 2:2", 13, Color(0.55, 0.72, 0.74, 0.9))
	map_label.position = Vector2(42, 116)
	map_label.size = Vector2(310, 26)
	root.add_child(map_label)

	rules_label = _label("FORMULA  //  2 PULSE", 15, GameConfig.COLOR_CYAN)
	rules_label.position = Vector2(42, 625)
	rules_label.size = Vector2(570, 30)
	root.add_child(rules_label)

	debug_label = _label("FPS 60  //  E 0  U 2  P 0", 13, Color(0.62, 0.72, 0.78, 0.86))
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	debug_label.position = Vector2(880, 633)
	debug_label.size = Vector2(350, 28)
	root.add_child(debug_label)

	status_label = _label("AUTO-FIRE  ONLINE", 13, Color(0.55, 0.72, 0.74, 0.9))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2(430, 64)
	status_label.size = Vector2(420, 26)
	root.add_child(status_label)

	hint_label = _label("WASD / ARROWS  MOVE      SPACE  BLINK", 16, GameConfig.COLOR_YELLOW)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.position = Vector2(390, 570)
	hint_label.size = Vector2(500, 36)
	root.add_child(hint_label)

	var xp_panel := Panel.new()
	xp_panel.position = Vector2(350, 672)
	xp_panel.size = Vector2(580, 30)
	xp_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(xp_panel)

	xp_bar = ProgressBar.new()
	xp_bar.position = Vector2(12, 9)
	xp_bar.size = Vector2(556, 12)
	xp_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.08, 0.12, 1)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	var fill := bg.duplicate()
	fill.bg_color = GameConfig.COLOR_YELLOW
	xp_bar.add_theme_stylebox_override("background", bg)
	xp_bar.add_theme_stylebox_override("fill", fill)
	xp_panel.add_child(xp_bar)

	xp_label = _label("ENERGY 0 / 20", 12, GameConfig.COLOR_WHITE)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.position = Vector2(0, -24)
	xp_label.size = Vector2(580, 24)
	xp_panel.add_child(xp_label)


func _build_upgrade_overlay() -> void:
	upgrade_overlay = ColorRect.new()
	upgrade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_overlay.color = Color(0.005, 0.012, 0.026, 0.94)
	upgrade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(upgrade_overlay)

	var top_rule := ColorRect.new()
	top_rule.position = Vector2(230, 102)
	top_rule.size = Vector2(820, 2)
	top_rule.color = GameConfig.COLOR_CYAN
	upgrade_overlay.add_child(top_rule)

	upgrade_title = _label("FORMULA ACQUIRED  //  SELECT ONE", 28, GameConfig.COLOR_WHITE)
	upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_title.position = Vector2(250, 120)
	upgrade_title.size = Vector2(780, 48)
	upgrade_overlay.add_child(upgrade_title)

	var subtitle := _label("전투 시간이 정지되었습니다", 14, Color(0.55, 0.72, 0.74, 1))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(390, 164)
	subtitle.size = Vector2(500, 28)
	upgrade_overlay.add_child(subtitle)

	for index in range(3):
		var button := Button.new()
		button.position = Vector2(100 + index * 366, 225)
		button.size = Vector2(348, 276)
		button.text = "FORMULA"
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", GameConfig.COLOR_WHITE)
		button.add_theme_color_override("font_hover_color", GameConfig.COLOR_WHITE)
		button.add_theme_color_override("font_focus_color", GameConfig.COLOR_WHITE)
		button.add_theme_stylebox_override("normal", panel_style)
		button.add_theme_stylebox_override("hover", cyan_style)
		button.add_theme_stylebox_override("focus", cyan_style)
		button.add_theme_stylebox_override("pressed", cyan_style)
		button.pressed.connect(_on_card_pressed.bind(index))
		upgrade_overlay.add_child(button)
		card_buttons.append(button)

	var keys := _label("[ 1 ]                                 [ 2 ]                                 [ 3 ]", 14, GameConfig.COLOR_YELLOW)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.position = Vector2(100, 520)
	keys.size = Vector2(1080, 30)
	upgrade_overlay.add_child(keys)
	upgrade_overlay.visible = false


func _build_result_overlay() -> void:
	result_overlay = ColorRect.new()
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.color = Color(0.005, 0.012, 0.026, 0.96)
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(result_overlay)

	result_title = _label("FORMULA VERIFIED", 38, GameConfig.COLOR_CYAN)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.position = Vector2(260, 120)
	result_title.size = Vector2(760, 60)
	result_overlay.add_child(result_title)

	result_stats = _label("", 20, GameConfig.COLOR_WHITE)
	result_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_stats.position = Vector2(300, 190)
	result_stats.size = Vector2(680, 300)
	result_overlay.add_child(result_stats)

	var restart := Button.new()
	restart.text = "RECOMPILE RUN  //  ENTER · SPACE"
	restart.position = Vector2(430, 535)
	restart.size = Vector2(420, 64)
	restart.add_theme_font_size_override("font_size", 18)
	restart.add_theme_color_override("font_color", GameConfig.COLOR_WHITE)
	restart.add_theme_stylebox_override("normal", cyan_style)
	restart.add_theme_stylebox_override("hover", cyan_style)
	restart.add_theme_stylebox_override("focus", cyan_style)
	restart.pressed.connect(func(): restart_requested.emit())
	result_overlay.add_child(restart)
	result_overlay.visible = false


func _build_pause_overlay() -> void:
	pause_overlay = ColorRect.new()
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.color = Color(0.005, 0.012, 0.026, 0.84)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pause_overlay)
	var label := _label("PROCESS PAUSED\n\nESC / START  RESUME", 28, GameConfig.COLOR_WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(label)
	pause_overlay.visible = false


func update_hud(data: Dictionary) -> void:
	var health_cells := ""
	for index in range(data.max_hp):
		health_cells += "◆ " if index < data.hp else "◇ "
	health_label.text = "CORE  " + health_cells
	health_label.add_theme_color_override("font_color", GameConfig.COLOR_RED if data.hp <= 1 else GameConfig.COLOR_WHITE)

	var seconds: int = ceili(data.remaining)
	timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	timer_label.add_theme_color_override("font_color", GameConfig.COLOR_RED if seconds <= 30 else GameConfig.COLOR_WHITE)
	score_label.text = "SCORE  %06d  //  RISK ×%.2f" % [data.score, data.risk]
	formation_label.text = "FORMATION  //  " + data.formation
	map_label.text = "MAP 3×3  //  SECTOR " + data.sector
	rules_label.text = "FORMULA  //  " + data.formula
	debug_label.text = "FPS %d  //  E %d  U %d  P %d" % [Engine.get_frames_per_second(), data.enemies, data.units, data.projectiles]
	xp_bar.max_value = data.xp_needed
	xp_bar.value = data.xp
	xp_label.text = "ENERGY  %d / %d" % [data.xp, data.xp_needed]
	hint_label.modulate.a = clampf((15.0 - data.elapsed) / 4.0, 0.0, 1.0)
	status_label.text = "ROUND %02d  //  BLINK %03d%%  //  AUTO-FIRE ONLINE" % [data.round, int(data.blink * 100.0)]


func show_upgrade(options: Array, level: int) -> void:
	upgrade_title.text = "LEVEL %02d  //  SELECT NEW FORMULA" % level
	for index in range(3):
		var option: Dictionary = options[index]
		card_buttons[index].set_meta("upgrade_id", option.id)
		card_buttons[index].text = "%s\n\n%s\n\n%s\n\n%s" % [option.name, option.formula, option.description, option.forecast]
	upgrade_overlay.visible = true
	card_buttons[0].grab_focus()


func hide_upgrade() -> void:
	upgrade_overlay.visible = false


func choose_card(index: int) -> void:
	if not upgrade_overlay.visible or index < 0 or index >= card_buttons.size():
		return
	_on_card_pressed(index)


func _on_card_pressed(index: int) -> void:
	upgrade_chosen.emit(str(card_buttons[index].get_meta("upgrade_id")))


func show_result(won: bool, stats: Dictionary) -> void:
	result_title.text = "FORMULA VERIFIED" if won else "FORMULA COLLAPSED"
	result_title.add_theme_color_override("font_color", GameConfig.COLOR_CYAN if won else GameConfig.COLOR_RED)
	result_stats.text = "%s\n\nSCORE  %06d    //    BEST  %06d\nSURVIVAL  %s    //    KILLS  %d\nMAX SWARM  %d    //    MITOSIS  %d\n\nFINAL FORMULA\n%s" % [
		"RUN COMPLETE" if won else "CORE TERMINATED",
		stats.score,
		stats.best,
		stats.survival,
		stats.kills,
		stats.max_units,
		stats.mitosis_count,
		stats.formula
	]
	result_overlay.visible = true


func hide_result() -> void:
	result_overlay.visible = false


func show_paused(value: bool) -> void:
	pause_overlay.visible = value
