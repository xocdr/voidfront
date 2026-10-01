extends CanvasLayer

var health_bar_bg: ColorRect
var health_bar_fill: ColorRect
var health_label: Label
var kill_label: Label
var special_label: Label
var warning_label: Label
var time_label: Label
var objective_label: Label
var wave_label: Label
var special_bar_bg: ColorRect
var special_bar_fill: ColorRect

const BAR_WIDTH: float = 220.0
const BAR_HEIGHT: float = 16.0
const SPECIAL_BAR_WIDTH: float = 160.0
const SPECIAL_BAR_HEIGHT: float = 8.0

func _ready() -> void:
	layer = 10
	_create_ui()

func _create_ui() -> void:
	# --- Top-left: Health bar + kills ---
	var top_left := VBoxContainer.new()
	top_left.anchor_left = 0.0
	top_left.anchor_top = 0.0
	top_left.offset_left = 24.0
	top_left.offset_top = 16.0
	top_left.add_theme_constant_override("separation", 6)
	add_child(top_left)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	top_left.add_child(hp_row)

	var hp_icon := Label.new()
	hp_icon.text = "HP"
	hp_icon.add_theme_font_size_override("font_size", 14)
	hp_icon.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8))
	hp_row.add_child(hp_icon)

	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	hp_row.add_child(bar_container)

	health_bar_bg = ColorRect.new()
	health_bar_bg.color = Color(0.12, 0.12, 0.18, 0.8)
	health_bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_container.add_child(health_bar_bg)

	health_bar_fill = ColorRect.new()
	health_bar_fill.color = Color(0.2, 0.8, 1.0)
	health_bar_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_container.add_child(health_bar_fill)

	var bar_border := ColorRect.new()
	bar_border.color = Color(0.3, 0.6, 0.8, 0.3)
	bar_border.size = Vector2(BAR_WIDTH, 1)
	bar_container.add_child(bar_border)

	health_label = Label.new()
	health_label.text = "100"
	health_label.add_theme_font_size_override("font_size", 14)
	health_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	hp_row.add_child(health_label)

	kill_label = Label.new()
	kill_label.text = "KILLS: 0"
	kill_label.add_theme_font_size_override("font_size", 16)
	kill_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	top_left.add_child(kill_label)

	var special_row := HBoxContainer.new()
	special_row.add_theme_constant_override("separation", 6)
	top_left.add_child(special_row)

	special_label = Label.new()
	special_label.text = "BURST"
	special_label.add_theme_font_size_override("font_size", 12)
	special_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.3))
	special_row.add_child(special_label)

	var sbar_container := Control.new()
	sbar_container.custom_minimum_size = Vector2(SPECIAL_BAR_WIDTH, SPECIAL_BAR_HEIGHT)
	special_row.add_child(sbar_container)

	special_bar_bg = ColorRect.new()
	special_bar_bg.color = Color(0.1, 0.1, 0.15, 0.7)
	special_bar_bg.size = Vector2(SPECIAL_BAR_WIDTH, SPECIAL_BAR_HEIGHT)
	sbar_container.add_child(special_bar_bg)

	special_bar_fill = ColorRect.new()
	special_bar_fill.color = Color(0.6, 0.9, 0.2)
	special_bar_fill.size = Vector2(SPECIAL_BAR_WIDTH, SPECIAL_BAR_HEIGHT)
	sbar_container.add_child(special_bar_fill)

	# --- Top-center: Objective (anchored center-top) ---
	objective_label = Label.new()
	objective_label.text = ""
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 20)
	objective_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	objective_label.anchor_left = 0.3
	objective_label.anchor_right = 0.7
	objective_label.anchor_top = 0.0
	objective_label.offset_top = 16.0
	objective_label.offset_bottom = 46.0
	add_child(objective_label)

	# --- Top-right: Time + Wave ---
	var top_right := VBoxContainer.new()
	top_right.anchor_left = 1.0
	top_right.anchor_top = 0.0
	top_right.offset_left = -180.0
	top_right.offset_top = 16.0
	top_right.add_theme_constant_override("separation", 4)
	add_child(top_right)

	time_label = Label.new()
	time_label.text = "0:00"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.add_theme_font_size_override("font_size", 20)
	time_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	top_right.add_child(time_label)

	wave_label = Label.new()
	wave_label.text = ""
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wave_label.add_theme_font_size_override("font_size", 14)
	wave_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	top_right.add_child(wave_label)

	# Boundary warning (centered)
	warning_label = Label.new()
	warning_label.text = "// LEAVING COMBAT ZONE //"
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 24)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2, 0.9))
	warning_label.anchor_left = 0.25
	warning_label.anchor_right = 0.75
	warning_label.anchor_top = 0.0
	warning_label.offset_top = 60.0
	warning_label.offset_bottom = 100.0
	warning_label.visible = false
	add_child(warning_label)

func update_display(hp: float, max_hp: float, kills: int, special_ready: bool, boundary: bool, elapsed: float) -> void:
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	health_bar_fill.size.x = BAR_WIDTH * ratio

	if ratio < 0.3:
		health_bar_fill.color = Color(1.0, 0.25, 0.15)
	elif ratio < 0.6:
		health_bar_fill.color = Color(1.0, 0.7, 0.2)
	else:
		health_bar_fill.color = Color(0.2, 0.8, 1.0)

	health_label.text = "%d" % ceili(hp)
	kill_label.text = "KILLS: %d" % kills

	if special_ready:
		special_bar_fill.size.x = SPECIAL_BAR_WIDTH
		special_bar_fill.color = Color(0.6, 0.9, 0.2)
		special_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.3))
	else:
		special_bar_fill.size.x = 0
		special_bar_fill.color = Color(0.3, 0.4, 0.2)
		special_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))

	warning_label.visible = boundary

	var minutes := int(elapsed) / 60
	var seconds := int(elapsed) % 60
	time_label.text = "%d:%02d" % [minutes, seconds]

func update_objective(text: String) -> void:
	objective_label.text = text

func update_wave(current: int, total: int) -> void:
	if total > 0:
		wave_label.text = "WAVE %d/%d" % [current, total]
	else:
		wave_label.text = ""

func show_death_message() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.1, 0.0, 0.0, 0.4)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var death_label := Label.new()
	death_label.text = "DESTROYED"
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.add_theme_font_size_override("font_size", 52)
	death_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.1))
	death_label.anchor_left = 0.25
	death_label.anchor_right = 0.75
	death_label.anchor_top = 0.4
	death_label.anchor_bottom = 0.5
	add_child(death_label)

	var sub_label := Label.new()
	sub_label.text = "Returning to base..."
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 18)
	sub_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.5))
	sub_label.anchor_left = 0.25
	sub_label.anchor_right = 0.75
	sub_label.anchor_top = 0.5
	sub_label.anchor_bottom = 0.55
	add_child(sub_label)

func show_mission_complete_banner() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.05, 0.0, 0.3)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var banner := Label.new()
	banner.text = "MISSION COMPLETE"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 52)
	banner.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	banner.anchor_left = 0.2
	banner.anchor_right = 0.8
	banner.anchor_top = 0.4
	banner.anchor_bottom = 0.5
	add_child(banner)
