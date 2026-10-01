extends Control

var mission_label: Label
var obj_container: VBoxContainer
var prev_btn: Button
var next_btn: Button
var start_button: Button
var back_button: Button
var center: VBoxContainer
var selector_row: HBoxContainer

func _ready() -> void:
	_create_ui()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()

func _create_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.08, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	center = VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.custom_minimum_size = Vector2(400, 0)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 16)
	add_child(center)

	var title_label := Label.new()
	title_label.text = "MISSIONS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	center.add_child(title_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	center.add_child(spacer)

	selector_row = HBoxContainer.new()
	selector_row.alignment = BoxContainer.ALIGNMENT_CENTER
	selector_row.add_theme_constant_override("separation", 16)
	center.add_child(selector_row)

	prev_btn = Button.new()
	prev_btn.text = "◀"
	prev_btn.custom_minimum_size = Vector2(56, 56)
	prev_btn.pressed.connect(_on_prev_mission)
	selector_row.add_child(prev_btn)

	mission_label = Label.new()
	mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_label.add_theme_font_size_override("font_size", 24)
	mission_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	selector_row.add_child(mission_label)

	next_btn = Button.new()
	next_btn.text = "▶"
	next_btn.custom_minimum_size = Vector2(56, 56)
	next_btn.pressed.connect(_on_next_mission)
	selector_row.add_child(next_btn)

	obj_container = VBoxContainer.new()
	obj_container.add_theme_constant_override("separation", 4)
	center.add_child(obj_container)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 16)
	center.add_child(spacer2)

	start_button = _make_button("START MISSION", center)
	start_button.pressed.connect(_on_start_pressed)

	back_button = _make_button("BACK", center)
	back_button.pressed.connect(_on_back_pressed)

	start_button.grab_focus()
	_update_mission_display()

func _apply_responsive_layout() -> void:
	var vp_w: float = get_viewport_rect().size.x
	var margin: float = 40.0
	var content_w: float = clampf(vp_w - margin, 160.0, 400.0)
	center.custom_minimum_size.x = content_w

	var btn_w: float = minf(320.0, content_w)
	start_button.custom_minimum_size.x = btn_w
	back_button.custom_minimum_size.x = btn_w

	var nav_btn_size: float = 40.0 if content_w < 220.0 else 56.0
	prev_btn.custom_minimum_size = Vector2(nav_btn_size, nav_btn_size)
	next_btn.custom_minimum_size = Vector2(nav_btn_size, nav_btn_size)

	var label_w: float = maxf(80.0, content_w - nav_btn_size * 2.0 - 32.0)
	mission_label.custom_minimum_size.x = label_w

func _update_mission_display() -> void:
	var mission := MissionRegistry.get_mission(GameState.current_mission_id)
	if mission:
		mission_label.text = "Mission %d: %s" % [mission.id, mission.mission_name]
		for child in obj_container.get_children():
			child.queue_free()
		for obj in mission.objectives:
			var lbl := Label.new()
			lbl.text = "• %s" % obj.description
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			obj_container.add_child(lbl)

	var locked := GameState.current_mission_id > GameState.highest_unlocked
	start_button.disabled = locked
	if locked:
		start_button.text = "LOCKED"
	else:
		start_button.text = "START MISSION"

	prev_btn.disabled = GameState.current_mission_id <= 1
	next_btn.disabled = GameState.current_mission_id >= MissionRegistry.get_mission_count()

func _on_prev_mission() -> void:
	AudioManager.play_menu_select()
	GameState.current_mission_id = maxi(1, GameState.current_mission_id - 1)
	_update_mission_display()

func _on_next_mission() -> void:
	AudioManager.play_menu_select()
	GameState.current_mission_id = mini(MissionRegistry.get_mission_count(), GameState.current_mission_id + 1)
	_update_mission_display()

func _make_button(text: String, parent: Node) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(320, 60)
	btn.add_theme_font_size_override("font_size", 20)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(btn)
	return btn

func _on_start_pressed() -> void:
	AudioManager.play_menu_select()
	start_button.disabled = true
	back_button.disabled = true

	var mission := MissionRegistry.get_mission(GameState.current_mission_id)
	if mission and not mission.briefing_text.is_empty():
		var cutscene := CutscenePlayer.create(mission.briefing_text, "COMMAND")
		add_child(cutscene)
		cutscene.cutscene_finished.connect(_on_briefing_done)
	else:
		_on_briefing_done()

func _on_briefing_done() -> void:
	var hs := HyperspeedTransition.create()
	add_child(hs)
	hs.transition_midpoint.connect(func():
		get_tree().change_scene_to_file("res://src/mission/mission_runner.tscn")
	)
	hs.play()

func _on_back_pressed() -> void:
	AudioManager.play_menu_select()
	SceneTransition.change_scene("res://src/ui/main_menu.tscn")
