extends Control

# Audio settings: Music and Sound Effects on/off, saved by AudioManager.

var center: VBoxContainer
var music_button: Button
var sfx_button: Button
var back_button: Button

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
	center.custom_minimum_size = UiScale.vec(Vector2(400, 0))
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", roundi(UiScale.px(14.0)))
	add_child(center)

	var title_label := Label.new()
	title_label.text = "SETTINGS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", UiScale.fs(40))
	title_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	center.add_child(title_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = UiScale.vec(Vector2(0, 12))
	center.add_child(spacer)

	music_button = _make_toggle()
	music_button.button_pressed = AudioManager.music_enabled
	music_button.toggled.connect(_on_music_toggled)
	center.add_child(music_button)

	sfx_button = _make_toggle()
	sfx_button.button_pressed = AudioManager.sfx_enabled
	sfx_button.toggled.connect(_on_sfx_toggled)
	center.add_child(sfx_button)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = UiScale.vec(Vector2(0, 12))
	center.add_child(spacer2)

	back_button = Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size = UiScale.vec(Vector2(320, 60))
	back_button.add_theme_font_size_override("font_size", UiScale.fs(20))
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(_on_back_pressed)
	center.add_child(back_button)

	_refresh_labels()
	back_button.grab_focus()

func _make_toggle() -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = UiScale.vec(Vector2(320, 60))
	b.add_theme_font_size_override("font_size", UiScale.fs(20))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b

func _refresh_labels() -> void:
	music_button.text = "MUSIC:  %s" % ("ON" if music_button.button_pressed else "OFF")
	sfx_button.text = "SOUND EFFECTS:  %s" % ("ON" if sfx_button.button_pressed else "OFF")
	for b in [music_button, sfx_button]:
		var c := Color(0.4, 0.9, 1.0) if b.button_pressed else Color(0.55, 0.55, 0.6)
		b.add_theme_color_override("font_color", c)
		b.add_theme_color_override("font_pressed_color", c)
		b.add_theme_color_override("font_hover_color", c)
		b.add_theme_color_override("font_hover_pressed_color", c)
		b.add_theme_color_override("font_focus_color", c)

func _on_music_toggled(on: bool) -> void:
	AudioManager.set_music_enabled(on)
	AudioManager.play_menu_select()
	_refresh_labels()

func _on_sfx_toggled(on: bool) -> void:
	AudioManager.set_sfx_enabled(on)
	# Plays only when turning sound effects on, giving audible confirmation.
	AudioManager.play_menu_select()
	_refresh_labels()

func _apply_responsive_layout() -> void:
	var vp_w: float = get_viewport_rect().size.x
	var content_w: float = clampf(vp_w - 40.0, 160.0, maxf(UiScale.px(400.0), 160.0))
	center.custom_minimum_size.x = content_w
	var btn_w: float = minf(UiScale.px(320.0), content_w)
	for b in [music_button, sfx_button, back_button]:
		b.custom_minimum_size.x = btn_w

func _on_back_pressed() -> void:
	AudioManager.play_menu_select()
	SceneTransition.change_scene("res://src/ui/main_menu.tscn")
