extends Control

var title_label: Label
var start_button: Button
var hangar_button: Button
var missions_button: Button
var settings_button: Button
var store_button: Button
var quit_button: Button
var center: VBoxContainer
var subtitle_label: Label
var top_spacer: Control

func _ready() -> void:
	_create_ui()
	AudioManager.play_menu_music()
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
	center.custom_minimum_size = UiScale.vec(Vector2(400, 0))
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 16)
	add_child(center)

	title_label = Label.new()
	title_label.text = "VOIDFRONT"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", UiScale.fs(64))
	title_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	center.add_child(title_label)

	subtitle_label = Label.new()
	var subtitle := subtitle_label
	subtitle.text = "Content Prototype"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", UiScale.fs(18))
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	center.add_child(subtitle)

	top_spacer = Control.new()
	var spacer := top_spacer
	spacer.custom_minimum_size = Vector2(0, 20)
	center.add_child(spacer)

	start_button = _make_button("START GAME", center)
	start_button.pressed.connect(_on_start_pressed)

	hangar_button = _make_button("HANGAR", center)
	hangar_button.pressed.connect(_on_hangar_pressed)

	missions_button = _make_button("MISSIONS", center)
	missions_button.pressed.connect(_on_missions_pressed)

	settings_button = _make_button("SETTINGS", center)
	settings_button.pressed.connect(_on_settings_pressed)

	store_button = _make_button("STORE", center)
	store_button.pressed.connect(_on_store_pressed)

	quit_button = _make_button("QUIT", center)
	quit_button.pressed.connect(_on_quit_pressed)

	start_button.grab_focus()

func _apply_responsive_layout() -> void:
	var vp_w: float = get_viewport_rect().size.x
	var margin: float = 40.0
	var content_w: float = clampf(vp_w - margin, 160.0, maxf(UiScale.px(400.0), 160.0))
	center.custom_minimum_size.x = content_w

	var narrow: bool = vp_w < 500.0
	# Short landscape screens (a phone, or a foldable's cover screen) can't fit the
	# full stack at phone text size, so drop the subtitle and tighten the buttons.
	var compact: bool = get_viewport_rect().size.y < UiScale.px(640.0)
	title_label.add_theme_font_size_override("font_size", UiScale.fs(40 if (narrow or compact) else 64))
	subtitle_label.visible = not compact
	top_spacer.custom_minimum_size.y = UiScale.px(4.0 if compact else 20.0)
	center.add_theme_constant_override("separation", roundi(UiScale.px(8.0 if compact else 16.0)))

	var btn_w: float = minf(UiScale.px(320.0), content_w)
	var btn_h: float = UiScale.px(46.0 if compact else 60.0)
	for btn in [start_button, hangar_button, missions_button, settings_button, store_button, quit_button]:
		btn.custom_minimum_size = Vector2(btn_w, btn_h)

func _make_button(text: String, parent: Node) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = UiScale.vec(Vector2(320, 60))
	btn.add_theme_font_size_override("font_size", UiScale.fs(20))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(btn)
	return btn

func _on_start_pressed() -> void:
	AudioManager.play_menu_select()
	_set_buttons_disabled(true)
	# Clear the menu so the briefing and warp play over plain space, not the menu.
	center.visible = false

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

func _on_hangar_pressed() -> void:
	AudioManager.play_menu_select()
	SceneTransition.change_scene("res://src/ui/hangar_menu.tscn")

func _on_missions_pressed() -> void:
	AudioManager.play_menu_select()
	SceneTransition.change_scene("res://src/ui/missions_menu.tscn")

func _on_settings_pressed() -> void:
	AudioManager.play_menu_select()
	SceneTransition.change_scene("res://src/ui/settings_menu.tscn")

func _on_store_pressed() -> void:
	AudioManager.play_menu_select()
	SceneTransition.change_scene("res://src/ui/store_menu.tscn")

func _on_quit_pressed() -> void:
	AudioManager.play_menu_select()
	get_tree().quit()

func _set_buttons_disabled(disabled: bool) -> void:
	for btn in [start_button, hangar_button, missions_button, settings_button, store_button, quit_button]:
		btn.disabled = disabled
