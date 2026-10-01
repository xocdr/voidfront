extends Control

var loadouts: Array[ShipLoadoutData] = []
var index: int = 0
var selected_category: String = ""

var root_row: BoxContainer
var nav_column: VBoxContainer
var category_buttons: Dictionary = {}
var card_list: VBoxContainer

var center_column: VBoxContainer
var ship_selector_row: HBoxContainer
var prev_btn: Button
var next_btn: Button
var name_label: Label
var credits_label: Label
var ship_display: HangarShipDisplay
var back_button: Button

var stats_column: VBoxContainer
var stats_rows: Dictionary = {}
var _last_stats: Dictionary = {}
var _stat_tweens: Dictionary = {}

func _ready() -> void:
	loadouts = ShipLoadoutRegistry.get_all_loadouts()
	index = _find_selected_index()
	selected_category = UpgradeRegistry.get_categories()[0]
	_create_ui()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()

func _find_selected_index() -> int:
	for i in loadouts.size():
		if loadouts[i].id == GameState.selected_loadout_id:
			return i
	return 0

func _current_loadout() -> ShipLoadoutData:
	return loadouts[index]

func _current_equipment() -> ShipEquipmentState:
	return GameState.get_equipment_for(_current_loadout().id)

func _create_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.08, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	root_row = BoxContainer.new()
	root_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_row.add_theme_constant_override("separation", 16)
	add_child(root_row)

	_build_nav_column()
	_build_center_column()
	_build_stats_column()

	_update_all()

func _build_nav_column() -> void:
	nav_column = VBoxContainer.new()
	nav_column.custom_minimum_size = Vector2(220, 0)
	nav_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav_column.add_theme_constant_override("separation", 8)
	root_row.add_child(nav_column)

	var title := Label.new()
	title.text = "UPGRADES"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	nav_column.add_child(title)

	for category in UpgradeRegistry.get_categories():
		var btn := Button.new()
		btn.text = category.to_upper()
		btn.toggle_mode = true
		btn.pressed.connect(_on_category_selected.bind(category))
		nav_column.add_child(btn)
		category_buttons[category] = btn

	var card_scroll := ScrollContainer.new()
	card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav_column.add_child(card_scroll)

	card_list = VBoxContainer.new()
	card_list.add_theme_constant_override("separation", 6)
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_scroll.add_child(card_list)

func _build_center_column() -> void:
	center_column = VBoxContainer.new()
	center_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_column.alignment = BoxContainer.ALIGNMENT_CENTER
	center_column.add_theme_constant_override("separation", 8)
	root_row.add_child(center_column)

	var title_label := Label.new()
	title_label.text = "HANGAR"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	center_column.add_child(title_label)

	credits_label = Label.new()
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_label.add_theme_font_size_override("font_size", 18)
	credits_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	center_column.add_child(credits_label)

	ship_selector_row = HBoxContainer.new()
	ship_selector_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ship_selector_row.add_theme_constant_override("separation", 16)
	center_column.add_child(ship_selector_row)

	prev_btn = Button.new()
	prev_btn.text = "◀"
	prev_btn.custom_minimum_size = Vector2(56, 56)
	prev_btn.pressed.connect(_on_prev_pressed)
	ship_selector_row.add_child(prev_btn)

	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	ship_selector_row.add_child(name_label)

	next_btn = Button.new()
	next_btn.text = "▶"
	next_btn.custom_minimum_size = Vector2(56, 56)
	next_btn.pressed.connect(_on_next_pressed)
	ship_selector_row.add_child(next_btn)

	ship_display = HangarShipDisplay.create(_current_loadout(), _current_equipment())
	ship_display.custom_minimum_size = Vector2(480, 480)
	ship_display.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center_column.add_child(ship_display)

	back_button = Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size = Vector2(320, 60)
	back_button.add_theme_font_size_override("font_size", 20)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(_on_back_pressed)
	center_column.add_child(back_button)

func _build_stats_column() -> void:
	stats_column = VBoxContainer.new()
	stats_column.custom_minimum_size = Vector2(220, 0)
	stats_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_column.add_theme_constant_override("separation", 6)
	root_row.add_child(stats_column)

	var title := Label.new()
	title.text = "SHIP STATS"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	stats_column.add_child(title)

	for stat_key in ["move_speed", "fire_cooldown", "special_damage", "max_hp"]:
		var row := HBoxContainer.new()
		stats_column.add_child(row)
		var label := Label.new()
		label.text = _stat_display_name(stat_key) + ":"
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		row.add_child(label)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 14)
		value.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		row.add_child(value)
		stats_rows[stat_key] = value

func _stat_display_name(stat_key: String) -> String:
	match stat_key:
		"move_speed": return "Speed"
		"fire_cooldown": return "Fire Rate"
		"special_damage": return "Special Dmg"
		"max_hp": return "Hull"
		_: return stat_key

func _apply_responsive_layout() -> void:
	var vp_w: float = get_viewport_rect().size.x
	if vp_w < 900.0:
		root_row.vertical = true
	else:
		root_row.vertical = false

func _on_category_selected(category: String) -> void:
	AudioManager.play_menu_select()
	selected_category = category
	_update_all()

func _update_all() -> void:
	_update_nav_buttons()
	_update_cards()
	_update_center()
	_update_stats(false)

func _update_nav_buttons() -> void:
	for category in category_buttons:
		category_buttons[category].button_pressed = (category == selected_category)

func _update_cards() -> void:
	for child in card_list.get_children():
		child.queue_free()

	var equipment := _current_equipment()
	for upgrade in UpgradeRegistry.get_upgrades(selected_category):
		card_list.add_child(_build_card(upgrade, equipment))

func _build_card(upgrade: UpgradeData, equipment: ShipEquipmentState) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)

	var name_lbl := Label.new()
	name_lbl.text = upgrade.display_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	card.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = upgrade.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	card.add_child(desc_lbl)

	var is_equipped: bool = equipment.equipped.get(upgrade.category, "") == upgrade.id
	var is_owned: bool = equipment.owned_upgrade_ids.has(upgrade.id)
	var mission_unlocked: bool = GameState.highest_unlocked >= upgrade.required_mission_id
	var can_afford: bool = GameState.credits >= upgrade.cost

	var action_btn := Button.new()
	if is_equipped:
		action_btn.text = "EQUIPPED"
		action_btn.disabled = true
	elif is_owned:
		action_btn.text = "EQUIP"
		action_btn.disabled = false
	elif not mission_unlocked:
		action_btn.text = "NEED MISSION %d" % upgrade.required_mission_id
		action_btn.disabled = true
	elif not can_afford:
		action_btn.text = "NOT ENOUGH CREDITS (%d)" % upgrade.cost
		action_btn.disabled = true
	else:
		action_btn.text = "BUY (%d)" % upgrade.cost
		action_btn.disabled = false

	action_btn.pressed.connect(_try_equip.bind(upgrade))
	card.add_child(action_btn)

	return card

func _try_equip(upgrade: UpgradeData) -> void:
	if UpgradeRegistry.get_upgrade(upgrade.id) == null:
		return

	if GameState.highest_unlocked < upgrade.required_mission_id:
		return

	var equipment := _current_equipment()
	var already_owned := equipment.owned_upgrade_ids.has(upgrade.id)

	if not already_owned:
		if GameState.credits < upgrade.cost:
			return
		GameState.credits -= upgrade.cost
		equipment.owned_upgrade_ids.append(upgrade.id)

	equipment.equipped[upgrade.category] = upgrade.id

	AudioManager.play_menu_select()
	ship_display.refresh_layer(upgrade.category, upgrade)
	ship_display.play_equip_feedback(upgrade.category)

	_update_cards()
	_update_center()
	_update_stats(true)

	SaveManager.save()

func _update_center() -> void:
	var loadout := _current_loadout()
	var unlocked := ShipLoadoutRegistry.is_unlocked(loadout)
	name_label.text = loadout.display_name
	credits_label.text = "CREDITS: %d" % GameState.credits
	prev_btn.disabled = index <= 0
	next_btn.disabled = index >= loadouts.size() - 1

func _update_stats(animate: bool) -> void:
	var loadout := _current_loadout()
	var equipment := _current_equipment()
	var stats := ShipStats.get_effective_stats(loadout, equipment)

	for stat_key in stats_rows:
		var value_label: Label = stats_rows[stat_key]
		var new_value: float = stats[stat_key]
		var old_value: float = _last_stats.get(stat_key, new_value)

		if _stat_tweens.has(stat_key):
			var existing_tween: Tween = _stat_tweens[stat_key]
			if existing_tween != null and existing_tween.is_valid():
				existing_tween.kill()
			_stat_tweens.erase(stat_key)

		if animate and not is_equal_approx(old_value, new_value):
			var tween := create_tween()
			tween.tween_method(
				func(v): value_label.text = _format_stat(stat_key, v),
				old_value, new_value, 0.3
			)
			_stat_tweens[stat_key] = tween
		else:
			value_label.text = _format_stat(stat_key, new_value)

	_last_stats = stats.duplicate()

func _format_stat(stat_key: String, value: float) -> String:
	match stat_key:
		"fire_cooldown": return "%.1f/s" % (1.0 / value)
		_: return "%d" % roundi(value)

func _on_prev_pressed() -> void:
	AudioManager.play_menu_select()
	index = maxi(0, index - 1)
	ship_display.set_ship(_current_loadout(), _current_equipment())
	_update_all()

func _on_next_pressed() -> void:
	AudioManager.play_menu_select()
	index = mini(loadouts.size() - 1, index + 1)
	ship_display.set_ship(_current_loadout(), _current_equipment())
	_update_all()

func _on_back_pressed() -> void:
	AudioManager.play_menu_select()
	if ShipLoadoutRegistry.is_unlocked(_current_loadout()) and GameState.selected_loadout_id != _current_loadout().id:
		GameState.selected_loadout_id = _current_loadout().id
		SaveManager.save()
	SceneTransition.change_scene("res://src/ui/main_menu.tscn")
