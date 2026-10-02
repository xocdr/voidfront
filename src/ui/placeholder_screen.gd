extends Control

@export var screen_title: String = "Coming Soon"

var center: VBoxContainer
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
	center.add_theme_constant_override("separation", 16)
	add_child(center)

	var title_label := Label.new()
	title_label.text = screen_title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", UiScale.fs(40))
	title_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	center.add_child(title_label)

	var subtitle := Label.new()
	subtitle.text = "Coming Soon"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", UiScale.fs(18))
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	center.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	center.add_child(spacer)

	back_button = Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size = UiScale.vec(Vector2(320, 60))
	back_button.add_theme_font_size_override("font_size", UiScale.fs(20))
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(_on_back_pressed)
	center.add_child(back_button)

	back_button.grab_focus()

func _apply_responsive_layout() -> void:
	var vp_w: float = get_viewport_rect().size.x
	var margin: float = 40.0
	var content_w: float = clampf(vp_w - margin, 160.0, maxf(UiScale.px(400.0), 160.0))
	center.custom_minimum_size.x = content_w
	back_button.custom_minimum_size.x = minf(UiScale.px(320.0), content_w)

func _on_back_pressed() -> void:
	AudioManager.play_menu_select()
	SceneTransition.change_scene("res://src/ui/main_menu.tscn")
