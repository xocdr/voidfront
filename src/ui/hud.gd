extends CanvasLayer

signal pause_requested

var pause_button: Button
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

var top_left: VBoxContainer
var top_right: VBoxContainer

const BASE_PAUSE_SIZE: float = 64.0
const BASE_BAR_WIDTH: float = 220.0
const BASE_BAR_HEIGHT: float = 16.0
const BASE_SPECIAL_BAR_WIDTH: float = 160.0
const BASE_SPECIAL_BAR_HEIGHT: float = 8.0

var pause_size: float = UiScale.px(BASE_PAUSE_SIZE)
var bar_width: float = UiScale.px(BASE_BAR_WIDTH)
var bar_height: float = UiScale.px(BASE_BAR_HEIGHT)
var special_bar_width: float = UiScale.px(BASE_SPECIAL_BAR_WIDTH)
var special_bar_height: float = UiScale.px(BASE_SPECIAL_BAR_HEIGHT)

func _ready() -> void:
	layer = 10
	_create_ui()

func _create_ui() -> void:
	# --- Top-left: Health bar + kills ---
	top_left = VBoxContainer.new()
	top_left.anchor_left = 0.0
	top_left.anchor_top = 0.0
	top_left.add_theme_constant_override("separation", 6)
	add_child(top_left)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	top_left.add_child(hp_row)

	var hp_icon := Label.new()
	hp_icon.text = "HP"
	hp_icon.add_theme_font_size_override("font_size", UiScale.fs(14))
	hp_icon.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8))
	hp_row.add_child(hp_icon)

	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(bar_width, bar_height)
	hp_row.add_child(bar_container)

	health_bar_bg = ColorRect.new()
	health_bar_bg.color = Color(0.12, 0.12, 0.18, 0.8)
	health_bar_bg.size = Vector2(bar_width, bar_height)
	bar_container.add_child(health_bar_bg)

	health_bar_fill = ColorRect.new()
	health_bar_fill.color = Color(0.2, 0.8, 1.0)
	health_bar_fill.size = Vector2(bar_width, bar_height)
	bar_container.add_child(health_bar_fill)

	var bar_border := ColorRect.new()
	bar_border.color = Color(0.3, 0.6, 0.8, 0.3)
	bar_border.size = Vector2(bar_width, 1)
	bar_container.add_child(bar_border)

	health_label = Label.new()
	health_label.text = "100"
	health_label.add_theme_font_size_override("font_size", UiScale.fs(14))
	health_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	hp_row.add_child(health_label)

	kill_label = Label.new()
	kill_label.text = "KILLS: 0"
	kill_label.add_theme_font_size_override("font_size", UiScale.fs(16))
	kill_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	top_left.add_child(kill_label)

	var special_row := HBoxContainer.new()
	special_row.add_theme_constant_override("separation", 6)
	top_left.add_child(special_row)

	special_label = Label.new()
	special_label.text = "BURST"
	special_label.add_theme_font_size_override("font_size", UiScale.fs(12))
	special_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.3))
	special_row.add_child(special_label)

	var sbar_container := Control.new()
	sbar_container.custom_minimum_size = Vector2(special_bar_width, special_bar_height)
	special_row.add_child(sbar_container)

	special_bar_bg = ColorRect.new()
	special_bar_bg.color = Color(0.1, 0.1, 0.15, 0.7)
	special_bar_bg.size = Vector2(special_bar_width, special_bar_height)
	sbar_container.add_child(special_bar_bg)

	special_bar_fill = ColorRect.new()
	special_bar_fill.color = Color(0.6, 0.9, 0.2)
	special_bar_fill.size = Vector2(special_bar_width, special_bar_height)
	sbar_container.add_child(special_bar_fill)

	# --- Top-center: Objective (anchored center-top) ---
	objective_label = Label.new()
	objective_label.text = ""
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", UiScale.fs(20))
	objective_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(objective_label)

	# --- Top-right: Time + Wave ---
	top_right = VBoxContainer.new()
	top_right.anchor_left = 1.0
	top_right.anchor_right = 1.0
	top_right.anchor_top = 0.0
	top_right.add_theme_constant_override("separation", 4)
	add_child(top_right)

	time_label = Label.new()
	time_label.text = "0:00"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.add_theme_font_size_override("font_size", UiScale.fs(20))
	time_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	top_right.add_child(time_label)

	wave_label = Label.new()
	wave_label.text = ""
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wave_label.add_theme_font_size_override("font_size", UiScale.fs(14))
	wave_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	top_right.add_child(wave_label)

	# Boundary warning (centered)
	warning_label = Label.new()
	warning_label.text = "// LEAVING COMBAT ZONE //"
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", UiScale.fs(24))
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2, 0.9))
	warning_label.anchor_left = 0.25
	warning_label.anchor_right = 0.75
	warning_label.anchor_top = 0.0
	warning_label.offset_top = UiScale.px(60.0)
	warning_label.offset_bottom = UiScale.px(100.0)
	warning_label.visible = false
	add_child(warning_label)

	# --- Top-right corner: Pause button ---
	pause_button = Button.new()
	pause_button.text = "II"
	pause_button.custom_minimum_size = Vector2(pause_size, pause_size)
	pause_button.add_theme_font_size_override("font_size", UiScale.fs(20))
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.focus_mode = Control.FOCUS_NONE
	add_child(pause_button)
	pause_button.pressed.connect(func(): pause_requested.emit())

	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()

# Re-fits the HUD to the current viewport: keeps clear of notches/rounded
# corners, keeps the top-right readout clear of the pause button, and drops the
# objective text onto its own row when the screen is too narrow to share the
# top bar with the HP panel.
func _apply_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var ins := TouchControls.get_safe_insets(get_viewport())
	var pad := UiScale.px(16.0)
	var left := ins.x + pad + UiScale.px(8.0)
	var right := ins.z + pad
	var top := ins.y + pad

	top_left.offset_left = left
	top_left.offset_top = top

	pause_button.offset_right = -right
	pause_button.offset_left = -right - pause_size
	pause_button.offset_top = top
	pause_button.offset_bottom = top + pause_size

	top_right.offset_right = -right - pause_size - UiScale.px(12.0)
	top_right.offset_left = top_right.offset_right - UiScale.px(160.0)
	top_right.offset_top = top

	var narrow := vp.x < 1100.0
	objective_label.add_theme_font_size_override("font_size", UiScale.fs(16 if narrow else 20))
	objective_label.anchor_top = 0.0
	objective_label.anchor_bottom = 0.0
	if narrow:
		objective_label.anchor_left = 0.0
		objective_label.anchor_right = 1.0
		objective_label.offset_left = left
		objective_label.offset_right = -right
		objective_label.offset_top = top + UiScale.px(96.0)
		objective_label.offset_bottom = top + UiScale.px(96.0) + UiScale.px(48.0)
	else:
		objective_label.anchor_left = 0.3
		objective_label.anchor_right = 0.7
		objective_label.offset_left = 0.0
		objective_label.offset_right = 0.0
		objective_label.offset_top = top
		objective_label.offset_bottom = top + UiScale.px(30.0)
	warning_label.offset_top = top + (UiScale.px(140.0) if narrow else UiScale.px(44.0))
	warning_label.offset_bottom = warning_label.offset_top + UiScale.px(40.0)

# Last values pushed to the controls. Setting a Label's text/theme override or a
# ColorRect's colour/size queues a redraw (and a re-layout) even when the value
# is unchanged, so only touch a control when its value actually changed.
var _last_hp: int = -1
var _last_ratio: float = -1.0
var _last_kills: int = -1
var _last_special_ready: int = -1
var _last_seconds: int = -1
var _last_objective: String = ""
var _objective_set: bool = false
var _last_wave_current: int = -1
var _last_wave_total: int = -1

func update_display(hp: float, max_hp: float, kills: int, special_ready: bool, boundary: bool, elapsed: float) -> void:
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	if not is_equal_approx(ratio, _last_ratio):
		_last_ratio = ratio
		health_bar_fill.size.x = bar_width * ratio
		if ratio < 0.3:
			health_bar_fill.color = Color(1.0, 0.25, 0.15)
		elif ratio < 0.6:
			health_bar_fill.color = Color(1.0, 0.7, 0.2)
		else:
			health_bar_fill.color = Color(0.2, 0.8, 1.0)

	var hp_int := ceili(hp)
	if hp_int != _last_hp:
		_last_hp = hp_int
		health_label.text = "%d" % hp_int

	if kills != _last_kills:
		_last_kills = kills
		kill_label.text = "KILLS: %d" % kills

	var special_flag := 1 if special_ready else 0
	if special_flag != _last_special_ready:
		_last_special_ready = special_flag
		if special_ready:
			special_bar_fill.size.x = special_bar_width
			special_bar_fill.color = Color(0.6, 0.9, 0.2)
			special_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.3))
		else:
			special_bar_fill.size.x = 0
			special_bar_fill.color = Color(0.3, 0.4, 0.2)
			special_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))

	if warning_label.visible != boundary:
		warning_label.visible = boundary

	var total_seconds := int(elapsed)
	if total_seconds != _last_seconds:
		_last_seconds = total_seconds
		time_label.text = "%d:%02d" % [total_seconds / 60, total_seconds % 60]

func update_objective(text: String) -> void:
	if _objective_set and text == _last_objective:
		return
	_objective_set = true
	_last_objective = text
	objective_label.text = text

func update_wave(current: int, total: int) -> void:
	if current == _last_wave_current and total == _last_wave_total:
		return
	_last_wave_current = current
	_last_wave_total = total
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
	death_label.add_theme_font_size_override("font_size", UiScale.fs(52))
	death_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.1))
	death_label.anchor_left = 0.25
	death_label.anchor_right = 0.75
	death_label.anchor_top = 0.4
	death_label.anchor_bottom = 0.5
	add_child(death_label)

	var sub_label := Label.new()
	sub_label.text = "Returning to base..."
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", UiScale.fs(18))
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
	banner.add_theme_font_size_override("font_size", UiScale.fs(52))
	banner.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	banner.anchor_left = 0.2
	banner.anchor_right = 0.8
	banner.anchor_top = 0.4
	banner.anchor_bottom = 0.5
	add_child(banner)
