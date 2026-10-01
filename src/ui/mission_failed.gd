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
	center.custom_minimum_size = Vector2(400, 0)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 20)
	add_child(center)

	var mission := MissionRegistry.get_mission(GameState.current_mission_id)
	var mission_name := mission.mission_name if mission else "Unknown"

	_add_label(center, "MISSION FAILED", 48, Color(1.0, 0.2, 0.2))
	_add_label(center, mission_name, 24, Color(0.8, 0.8, 0.8))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	center.add_child(spacer)

	var minutes := int(GameState.mission_time) / 60
	var seconds := int(GameState.mission_time) % 60
	_add_label(center, "Survived: %d:%02d" % [minutes, seconds], 20, Color(0.7, 0.7, 0.7))
	_add_label(center, "Kills: %d" % GameState.kills, 20, Color(0.7, 0.7, 0.7))

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	center.add_child(spacer2)

	var retry_btn := _make_button("RETRY", center)
	retry_btn.pressed.connect(func():
		SceneTransition.change_scene("res://src/mission/mission_runner.tscn")
	)

	var menu_btn := _make_button("MAIN MENU", center)
	menu_btn.pressed.connect(func():
		SceneTransition.change_scene("res://src/ui/main_menu.tscn")
	)

	retry_btn.grab_focus()

func _add_label(parent: Node, text: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)

func _make_button(text: String, parent: Node) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 56)
	btn.add_theme_font_size_override("font_size", 18)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(btn)
	return btn
