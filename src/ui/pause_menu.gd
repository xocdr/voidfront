class_name PauseMenu
extends CanvasLayer

signal resumed
signal main_menu_requested

var panel: PanelContainer
var resume_button: Button

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.03, 0.06, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.06, 0.1, 0.95)
	panel_style.border_color = Color(0.3, 0.6, 0.8, 0.4)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.content_margin_left = 40.0
	panel_style.content_margin_right = 40.0
	panel_style.content_margin_top = 32.0
	panel_style.content_margin_bottom = 32.0
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UiScale.fs(32))
	title.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	box.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)

	resume_button = _make_button("RESUME", box)
	resume_button.pressed.connect(_on_resume_pressed)

	var main_menu_button := _make_button("MAIN MENU", box)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

func _make_button(text: String, parent: Node) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = UiScale.vec(Vector2(240, 56))
	btn.add_theme_font_size_override("font_size", UiScale.fs(18))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(btn)
	return btn

func open() -> void:
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()

func close() -> void:
	visible = false
	get_tree().paused = false

func _on_resume_pressed() -> void:
	AudioManager.play_menu_select()
	close()
	resumed.emit()

func _on_main_menu_pressed() -> void:
	AudioManager.play_menu_select()
	close()
	main_menu_requested.emit()
