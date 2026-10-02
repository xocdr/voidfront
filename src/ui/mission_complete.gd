extends Control

func _ready() -> void:
	_create_ui()

func _create_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.08, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.custom_minimum_size = UiScale.vec(Vector2(400, 0))
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	var compact: bool = get_viewport_rect().size.y < UiScale.px(700.0)
	center.add_theme_constant_override("separation", roundi(UiScale.px(5.0 if compact else 16.0)))
	add_child(center)

	var mission := MissionRegistry.get_mission(GameState.current_mission_id)
	var mission_name := mission.mission_name if mission else "Unknown"

	_add_label(center, "MISSION COMPLETE", 48, Color(0.2, 1.0, 0.4))
	_add_label(center, mission_name, 24, Color(0.8, 0.8, 0.8))

	var spacer := Control.new()
	spacer.custom_minimum_size = UiScale.vec(Vector2(0, 4 if compact else 20))
	center.add_child(spacer)

	var minutes := int(GameState.mission_time) / 60
	var seconds := int(GameState.mission_time) % 60
	_add_label(center, "Time: %d:%02d" % [minutes, seconds], 20, Color(0.7, 0.7, 0.7))
	_add_label(center, "Kills: %d" % GameState.kills, 20, Color(0.7, 0.7, 0.7))
	_add_label(center, "Accuracy: %.1f%%" % GameState.get_accuracy(), 20, Color(0.7, 0.7, 0.7))
	_add_label(center, "Damage Taken: %d" % ceili(GameState.damage_taken), 20, Color(0.7, 0.7, 0.7))
	_add_label(center, "Shots Fired: %d" % GameState.shots_fired, 20, Color(0.7, 0.7, 0.7))

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = UiScale.vec(Vector2(0, 4 if compact else 24))
	center.add_child(spacer2)

	var next_id := GameState.current_mission_id + 1
	var has_next := MissionRegistry.get_mission(next_id) != null

	if has_next:
		var next_btn := _make_button("NEXT MISSION", center)
		next_btn.pressed.connect(func():
			GameState.current_mission_id = next_id
			SceneTransition.change_scene("res://src/mission/mission_runner.tscn")
		)

	var replay_btn := _make_button("REPLAY", center)
	replay_btn.pressed.connect(func():
		SceneTransition.change_scene("res://src/mission/mission_runner.tscn")
	)

	var menu_btn := _make_button("MAIN MENU", center)
	menu_btn.pressed.connect(func():
		SceneTransition.change_scene("res://src/ui/main_menu.tscn")
	)

	replay_btn.grab_focus()

func _add_label(parent: Node, text: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", UiScale.fs(size))
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)

func _make_button(text: String, parent: Node) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = UiScale.vec(Vector2(300, 56))
	btn.add_theme_font_size_override("font_size", UiScale.fs(18))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(btn)
	return btn
