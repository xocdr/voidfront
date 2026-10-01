extends Control

var loadouts: Array[ShipLoadoutData] = []
var index: int = 0

var center: VBoxContainer
var selector_row: HBoxContainer
var prev_btn: Button
var next_btn: Button
var name_label: Label
var preview_box: Control
var preview_shape: Polygon2D
var desc_label: Label
var stats_container: VBoxContainer
var lock_label: Label
var equip_button: Button
var back_button: Button

func _ready() -> void:
	loadouts = ShipLoadoutRegistry.get_all_loadouts()
	index = _find_selected_index()
	_create_ui()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()

func _find_selected_index() -> int:
	for i in loadouts.size():
		if loadouts[i].id == GameState.selected_loadout_id:
			return i
	return 0

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
	center.add_theme_constant_override("separation", 12)
	add_child(center)

	var title_label := Label.new()
	title_label.text = "HANGAR"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	center.add_child(title_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	center.add_child(spacer)

	selector_row = HBoxContainer.new()
	selector_row.alignment = BoxContainer.ALIGNMENT_CENTER
	selector_row.add_theme_constant_override("separation", 16)
	center.add_child(selector_row)

	prev_btn = Button.new()
	prev_btn.text = "◀"
	prev_btn.custom_minimum_size = Vector2(56, 56)
	prev_btn.pressed.connect(_on_prev_pressed)
	selector_row.add_child(prev_btn)

	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	selector_row.add_child(name_label)

	next_btn = Button.new()
	next_btn.text = "▶"
	next_btn.custom_minimum_size = Vector2(56, 56)
	next_btn.pressed.connect(_on_next_pressed)
	selector_row.add_child(next_btn)

	preview_box = Control.new()
	preview_box.custom_minimum_size = Vector2(160, 160)
	preview_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(preview_box)

	var preview_bg := ColorRect.new()
	preview_bg.color = Color(0.08, 0.08, 0.16, 1.0)
	preview_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_box.add_child(preview_bg)

	preview_shape = Polygon2D.new()
	preview_shape.position = Vector2(80, 80)
	preview_shape.scale = Vector2(4, 4)
	preview_box.add_child(preview_shape)

	desc_label = Label.new()
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	center.add_child(desc_label)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 4)
	center.add_child(spacer2)

	stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 2)
	center.add_child(stats_container)

	lock_label = Label.new()
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_label.add_theme_font_size_override("font_size", 14)
	lock_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	center.add_child(lock_label)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 12)
	center.add_child(spacer3)

	equip_button = _make_button("EQUIP", center)
	equip_button.pressed.connect(_on_equip_pressed)

	back_button = _make_button("BACK", center)
	back_button.pressed.connect(_on_back_pressed)

	_update_display()

func _apply_responsive_layout() -> void:
	var vp_w: float = get_viewport_rect().size.x
	var margin: float = 40.0
	var content_w: float = clampf(vp_w - margin, 160.0, 400.0)
	center.custom_minimum_size.x = content_w

	var btn_w: float = minf(320.0, content_w)
	equip_button.custom_minimum_size.x = btn_w
	back_button.custom_minimum_size.x = btn_w

	var nav_btn_size: float = 40.0 if content_w < 220.0 else 56.0
	prev_btn.custom_minimum_size = Vector2(nav_btn_size, nav_btn_size)
	next_btn.custom_minimum_size = Vector2(nav_btn_size, nav_btn_size)

	var label_w: float = maxf(80.0, content_w - nav_btn_size * 2.0 - 32.0)
	name_label.custom_minimum_size.x = label_w

func _update_display() -> void:
	var loadout := loadouts[index]
	var unlocked := ShipLoadoutRegistry.is_unlocked(loadout)
	var equipped := loadout.id == GameState.selected_loadout_id

	name_label.text = loadout.display_name
	desc_label.text = loadout.description

	preview_shape.polygon = loadout.polygon_points
	preview_shape.color = loadout.color if unlocked else Color(0.4, 0.4, 0.4)

	for child in stats_container.get_children():
		child.queue_free()
	_add_stat_row("Speed", "%d" % loadout.move_speed)
	_add_stat_row("Fire Rate", "%.1f/s" % (1.0 / loadout.fire_cooldown))
	_add_stat_row("Special Dmg", "%d" % loadout.special_damage)
	_add_stat_row("Hull", "%d" % loadout.max_hp)

	if unlocked:
		lock_label.visible = false
		equip_button.disabled = equipped
		equip_button.text = "EQUIPPED" if equipped else "EQUIP"
	else:
		lock_label.visible = true
		lock_label.text = "Unlocks after Mission %d" % (loadout.unlock_mission_id - 1)
		equip_button.disabled = true
		equip_button.text = "LOCKED"

	prev_btn.disabled = index <= 0
	next_btn.disabled = index >= loadouts.size() - 1

func _add_stat_row(label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	stats_container.add_child(row)

	var label := Label.new()
	label.text = "%s:" % label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	row.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	row.add_child(value)

func _make_button(text: String, parent: Node) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(320, 60)
	btn.add_theme_font_size_override("font_size", 20)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(btn)
	return btn

func _on_prev_pressed() -> void:
	AudioManager.play_menu_select()
	index = maxi(0, index - 1)
	_update_display()

func _on_next_pressed() -> void:
	AudioManager.play_menu_select()
	index = mini(loadouts.size() - 1, index + 1)
	_update_display()

func _on_equip_pressed() -> void:
	var loadout := loadouts[index]
	if not ShipLoadoutRegistry.is_unlocked(loadout):
		return
	AudioManager.play_menu_select()
	GameState.selected_loadout_id = loadout.id
	_update_display()

func _on_back_pressed() -> void:
	AudioManager.play_menu_select()
	SceneTransition.change_scene("res://src/ui/main_menu.tscn")
