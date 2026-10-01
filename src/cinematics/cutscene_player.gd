class_name CutscenePlayer
extends CanvasLayer

signal cutscene_finished

const CHAR_DELAY: float = 0.03
const FADE_DURATION: float = 0.3

var lines: Array[String] = []
var speaker_name: String = "COMMAND"
var current_line_index: int = 0
var is_playing: bool = false
var is_typing: bool = false

var bg: ColorRect
var dialogue_container: Control
var portrait_border: ColorRect
var portrait_panel: ColorRect
var text_bg_panel: ColorRect
var speaker_label: Label
var text_label: Label
var continue_hint: Label
var star_canvas: Control
var starfield_dots: Array[Dictionary] = []
var type_tween: Tween
var hint_tween: Tween

func _ready() -> void:
	layer = 90
	_build_ui()
	_generate_starfield()

func _build_ui() -> void:
	# Full-screen dark overlay
	bg = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.06, 0.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	star_canvas = Control.new()
	star_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	star_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(star_canvas)

	# Dialogue container anchored to bottom of screen
	dialogue_container = Control.new()
	dialogue_container.anchor_left = 0.0
	dialogue_container.anchor_right = 1.0
	dialogue_container.anchor_top = 1.0
	dialogue_container.anchor_bottom = 1.0
	dialogue_container.offset_left = 16.0
	dialogue_container.offset_right = -16.0
	dialogue_container.offset_top = -150.0
	dialogue_container.offset_bottom = -16.0
	dialogue_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dialogue_container)

	# Portrait border
	portrait_border = ColorRect.new()
	portrait_border.color = Color(0.15, 0.5, 0.8, 0.6)
	portrait_border.position = Vector2(0, 0)
	portrait_border.size = Vector2(104, 104)
	portrait_border.modulate.a = 0.0
	portrait_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_container.add_child(portrait_border)

	# Portrait panel
	portrait_panel = ColorRect.new()
	portrait_panel.color = Color(0.05, 0.08, 0.15, 1.0)
	portrait_panel.position = Vector2(2, 2)
	portrait_panel.size = Vector2(100, 100)
	portrait_panel.modulate.a = 0.0
	portrait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_container.add_child(portrait_panel)

	var icon := Label.new()
	icon.text = "◆"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.add_theme_font_size_override("font_size", 36)
	icon.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0, 0.7))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_panel.add_child(icon)

	# Text background — fills remaining width
	text_bg_panel = ColorRect.new()
	text_bg_panel.color = Color(0.03, 0.05, 0.1, 0.85)
	text_bg_panel.anchor_left = 0.0
	text_bg_panel.anchor_right = 1.0
	text_bg_panel.anchor_top = 0.0
	text_bg_panel.anchor_bottom = 1.0
	text_bg_panel.offset_left = 112.0
	text_bg_panel.offset_right = 0.0
	text_bg_panel.offset_top = 0.0
	text_bg_panel.offset_bottom = 0.0
	text_bg_panel.modulate.a = 0.0
	text_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_container.add_child(text_bg_panel)

	# Speaker name
	speaker_label = Label.new()
	speaker_label.text = ""
	speaker_label.position = Vector2(8, 6)
	speaker_label.add_theme_font_size_override("font_size", 14)
	speaker_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	speaker_label.modulate.a = 0.0
	speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_bg_panel.add_child(speaker_label)

	# Dialogue text
	text_label = Label.new()
	text_label.text = ""
	text_label.anchor_right = 1.0
	text_label.offset_left = 8.0
	text_label.offset_top = 28.0
	text_label.offset_right = -32.0
	text_label.offset_bottom = -8.0
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 18)
	text_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	text_label.modulate.a = 0.0
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_bg_panel.add_child(text_label)

	# Continue hint — bottom-right of text panel
	continue_hint = Label.new()
	continue_hint.text = "▼"
	continue_hint.anchor_left = 1.0
	continue_hint.anchor_top = 1.0
	continue_hint.offset_left = -24.0
	continue_hint.offset_top = -24.0
	continue_hint.add_theme_font_size_override("font_size", 16)
	continue_hint.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.6))
	continue_hint.modulate.a = 0.0
	continue_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_bg_panel.add_child(continue_hint)

func _generate_starfield() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(80):
		starfield_dots.append({
			"pos": Vector2(rng.randf() * vp_size.x, rng.randf() * vp_size.y),
			"size": rng.randf_range(0.5, 2.0),
			"brightness": rng.randf_range(0.2, 0.8),
		})
	star_canvas.queue_redraw()
	star_canvas.draw.connect(_draw_stars)

func _draw_stars() -> void:
	for dot in starfield_dots:
		var c := Color(dot["brightness"], dot["brightness"], dot["brightness"] + 0.1, bg.color.a)
		star_canvas.draw_circle(dot["pos"], dot["size"], c)

func play(p_lines: Array[String], p_speaker: String = "COMMAND") -> void:
	lines.clear()
	for l in p_lines:
		lines.append(l)
	speaker_name = p_speaker
	current_line_index = 0
	is_playing = true
	_fade_in()

func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(bg, "color:a", 0.92, FADE_DURATION)
	tween.parallel().tween_property(portrait_border, "modulate:a", 1.0, FADE_DURATION)
	tween.parallel().tween_property(portrait_panel, "modulate:a", 1.0, FADE_DURATION)
	tween.parallel().tween_property(text_bg_panel, "modulate:a", 1.0, FADE_DURATION)
	tween.parallel().tween_property(speaker_label, "modulate:a", 1.0, FADE_DURATION)
	tween.parallel().tween_property(text_label, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_callback(_show_current_line)

func _show_current_line() -> void:
	if current_line_index >= lines.size():
		_fade_out()
		return
	speaker_label.text = speaker_name
	continue_hint.modulate.a = 0.0
	is_typing = true
	_type_text(lines[current_line_index])

func _type_text(full_text: String) -> void:
	text_label.text = ""
	if type_tween and type_tween.is_valid():
		type_tween.kill()
	type_tween = create_tween()
	for i in range(full_text.length()):
		var partial := full_text.substr(0, i + 1)
		type_tween.tween_callback(func(): text_label.text = partial)
		type_tween.tween_interval(CHAR_DELAY)
	type_tween.tween_callback(_on_line_typed)

func _on_line_typed() -> void:
	is_typing = false
	continue_hint.modulate.a = 1.0
	if hint_tween and hint_tween.is_valid():
		hint_tween.kill()
	hint_tween = create_tween().set_loops()
	hint_tween.tween_property(continue_hint, "modulate:a", 0.3, 0.5)
	hint_tween.tween_property(continue_hint, "modulate:a", 1.0, 0.5)

func _fade_out() -> void:
	is_playing = false
	var tween := create_tween()
	tween.tween_property(bg, "color:a", 0.0, FADE_DURATION)
	tween.parallel().tween_property(portrait_border, "modulate:a", 0.0, FADE_DURATION)
	tween.parallel().tween_property(portrait_panel, "modulate:a", 0.0, FADE_DURATION)
	tween.parallel().tween_property(text_bg_panel, "modulate:a", 0.0, FADE_DURATION)
	tween.parallel().tween_property(speaker_label, "modulate:a", 0.0, FADE_DURATION)
	tween.parallel().tween_property(text_label, "modulate:a", 0.0, FADE_DURATION)
	tween.parallel().tween_property(continue_hint, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func():
		cutscene_finished.emit()
		queue_free()
	)

func _unhandled_input(event: InputEvent) -> void:
	if not is_playing:
		return
	if event is InputEventMouseButton and event.pressed:
		_advance()
	elif event is InputEventKey and event.pressed:
		_advance()
	elif event is InputEventScreenTouch and event.pressed:
		_advance()

func _advance() -> void:
	if is_typing:
		if type_tween and type_tween.is_valid():
			type_tween.kill()
		text_label.text = lines[current_line_index]
		_on_line_typed()
		return
	if hint_tween and hint_tween.is_valid():
		hint_tween.kill()
	current_line_index += 1
	_show_current_line()

static func create(p_lines: Array[String], p_speaker: String = "COMMAND") -> CutscenePlayer:
	var player := CutscenePlayer.new()
	player.call_deferred("play", p_lines, p_speaker)
	return player
