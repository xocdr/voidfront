extends Control

var loadouts: Array[ShipLoadoutData] = []
var index: int = 0
var selected_category: String = ""

var margin_box: MarginContainer
var root_column: VBoxContainer

var header_row: HBoxContainer
var back_button: Button
var credits_label: Label

var content_row: BoxContainer

# Left column: ship preview, ship selector, stats.
var ship_panel: VBoxContainer
var ship_selector_row: HBoxContainer
var prev_btn: Button
var next_btn: Button
var name_label: Label
var ship_display: HangarShipDisplay
var select_ship_button: Button
var stats_column: VBoxContainer
var stats_rows: Dictionary = {}
var _last_stats: Dictionary = {}
var _stat_tweens: Dictionary = {}

# Right column: category tabs and upgrade cards.
var right_panel: VBoxContainer
var tab_bar: HBoxContainer
var category_buttons: Dictionary = {}
var card_scroll: ScrollContainer
var card_grid: GridContainer

var _last_interacted_upgrade_id: String = ""
var _suppress_hover_preview: bool = false

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

	margin_box = MarginContainer.new()
	margin_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin_box)

	root_column = VBoxContainer.new()
	root_column.add_theme_constant_override("separation", roundi(UiScale.px(12.0)))
	margin_box.add_child(root_column)

	_build_header_row()

	content_row = BoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", roundi(UiScale.px(20.0)))
	root_column.add_child(content_row)

	_build_ship_panel()
	_build_right_panel()

	_update_all()

	# Nothing has keyboard/gamepad focus on scene entry by default, so Tab/Enter/
	# arrows do nothing until a mouse click sets focus somewhere. Seed it here.
	category_buttons[selected_category].grab_focus()

func _build_header_row() -> void:
	header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", roundi(UiScale.px(16.0)))
	root_column.add_child(header_row)

	back_button = Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size = UiScale.vec(Vector2(120, 48))
	back_button.add_theme_font_size_override("font_size", UiScale.fs(18))
	back_button.pressed.connect(_on_back_pressed)
	header_row.add_child(back_button)

	var title_label := Label.new()
	title_label.text = "HANGAR"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", UiScale.fs(32))
	title_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	header_row.add_child(title_label)

	credits_label = Label.new()
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credits_label.custom_minimum_size = UiScale.vec(Vector2(160, 0))
	credits_label.add_theme_font_size_override("font_size", UiScale.fs(18))
	credits_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	header_row.add_child(credits_label)

func _build_ship_panel() -> void:
	ship_panel = VBoxContainer.new()
	ship_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ship_panel.size_flags_stretch_ratio = 0.85
	ship_panel.add_theme_constant_override("separation", roundi(UiScale.px(8.0)))
	content_row.add_child(ship_panel)

	ship_selector_row = HBoxContainer.new()
	ship_selector_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ship_selector_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ship_selector_row.add_theme_constant_override("separation", roundi(UiScale.px(16.0)))
	ship_panel.add_child(ship_selector_row)

	prev_btn = Button.new()
	prev_btn.text = "◀"
	prev_btn.custom_minimum_size = UiScale.vec(Vector2(48, 48))
	prev_btn.add_theme_font_size_override("font_size", UiScale.fs(18))
	prev_btn.pressed.connect(_on_prev_pressed)
	ship_selector_row.add_child(prev_btn)

	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = UiScale.vec(Vector2(220, 0))
	name_label.add_theme_font_size_override("font_size", UiScale.fs(22))
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	ship_selector_row.add_child(name_label)

	next_btn = Button.new()
	next_btn.text = "▶"
	next_btn.custom_minimum_size = UiScale.vec(Vector2(48, 48))
	next_btn.add_theme_font_size_override("font_size", UiScale.fs(18))
	next_btn.pressed.connect(_on_next_pressed)
	ship_selector_row.add_child(next_btn)

	ship_display = HangarShipDisplay.create(_current_loadout(), _current_equipment())
	ship_display.custom_minimum_size = UiScale.vec(Vector2(200, 140))
	ship_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ship_panel.add_child(ship_display)

	select_ship_button = Button.new()
	select_ship_button.text = "SELECT SHIP"
	select_ship_button.custom_minimum_size = UiScale.vec(Vector2(260, 52))
	select_ship_button.add_theme_font_size_override("font_size", UiScale.fs(18))
	select_ship_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	select_ship_button.pressed.connect(_on_select_ship_pressed)
	ship_panel.add_child(select_ship_button)

	_build_stats_column()

func _build_stats_column() -> void:
	stats_column = VBoxContainer.new()
	stats_column.add_theme_constant_override("separation", roundi(UiScale.px(4.0)))
	ship_panel.add_child(stats_column)

	var title := Label.new()
	title.text = "SHIP STATS"
	title.add_theme_font_size_override("font_size", UiScale.fs(20))
	title.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	stats_column.add_child(title)

	for stat_key in ["move_speed", "fire_cooldown", "special_damage", "special_radius", "max_hp"]:
		var row := HBoxContainer.new()
		stats_column.add_child(row)
		var label := Label.new()
		label.text = _stat_display_name(stat_key)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", UiScale.fs(15))
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		row.add_child(label)
		var value := Label.new()
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_font_size_override("font_size", UiScale.fs(15))
		value.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		row.add_child(value)
		stats_rows[stat_key] = value

func _build_right_panel() -> void:
	right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.15
	right_panel.add_theme_constant_override("separation", roundi(UiScale.px(10.0)))
	content_row.add_child(right_panel)

	_build_tab_bar()

	card_scroll = ScrollContainer.new()
	card_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.resized.connect(_update_card_columns)
	right_panel.add_child(card_scroll)

	card_grid = GridContainer.new()
	card_grid.columns = 2
	card_grid.add_theme_constant_override("h_separation", roundi(UiScale.px(10.0)))
	card_grid.add_theme_constant_override("v_separation", roundi(UiScale.px(10.0)))
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_scroll.add_child(card_grid)

func _build_tab_bar() -> void:
	tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", roundi(UiScale.px(8.0)))
	right_panel.add_child(tab_bar)

	for category in UpgradeRegistry.get_categories():
		var btn := Button.new()
		btn.text = category.to_upper()
		btn.toggle_mode = true
		btn.custom_minimum_size = UiScale.vec(Vector2(90, 48))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", UiScale.fs(14))
		btn.add_theme_stylebox_override("pressed", _make_card_stylebox(CARD_STYLE_EQUIPPED))
		btn.add_theme_color_override("font_pressed_color", Color(0.2, 0.8, 1.0))
		btn.pressed.connect(_on_category_selected.bind(category))
		tab_bar.add_child(btn)
		category_buttons[category] = btn

func _stat_display_name(stat_key: String) -> String:
	match stat_key:
		"move_speed": return "Speed"
		"fire_cooldown": return "Fire Rate"
		"special_damage": return "Special Dmg"
		"special_radius": return "Special Radius"
		"max_hp": return "Hull"
		_: return stat_key

# Keeps clear of notches/gesture bars, puts the ship and the upgrade list side by
# side whenever both fit, and stacks them only on genuinely narrow viewports.
func _apply_responsive_layout() -> void:
	var vp := get_viewport_rect().size
	var ins := TouchControls.get_safe_insets(get_viewport())
	var pad := roundi(UiScale.px(20.0))
	margin_box.add_theme_constant_override("margin_left", roundi(ins.x) + pad)
	margin_box.add_theme_constant_override("margin_right", roundi(ins.z) + pad)
	margin_box.add_theme_constant_override("margin_top", roundi(ins.y) + pad)
	margin_box.add_theme_constant_override("margin_bottom", roundi(ins.w) + pad)

	var stacked := vp.x < UiScale.px(560.0)
	content_row.vertical = stacked
	ship_display.custom_minimum_size = UiScale.vec(Vector2(200, 160 if stacked else 140))
	_update_card_columns()

# Cards need a readable minimum width, so the column count follows the width the
# scroll area actually has.
func _update_card_columns() -> void:
	if card_scroll == null or card_grid == null:
		return
	card_grid.columns = clampi(int(card_scroll.size.x / UiScale.px(260.0)), 1, 3)

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
	# Deferred: this is always triggered from inside a Button's own "pressed"
	# handler (equip/buy, category tab, ship prev/next). Freeing and replacing
	# that same button synchronously, in the same frame it's handling its own
	# click, leaves the viewport's GUI focus/hover tracking pointing at stale
	# state and breaks all later input. Rebuilding at idle time avoids that.
	call_deferred("_rebuild_cards")

func _rebuild_cards() -> void:
	for child in card_grid.get_children():
		child.queue_free()

	var equipment := _current_equipment()
	var action_buttons_by_id: Dictionary = {}
	var first_enabled_button: Button = null
	for upgrade in UpgradeRegistry.get_upgrades(selected_category):
		var card := _build_card(upgrade, equipment)
		card_grid.add_child(card)
		var inner: Node = card.get_child(0)
		var action_btn: Button = inner.get_child(inner.get_child_count() - 1)
		action_buttons_by_id[upgrade.id] = action_btn
		if first_enabled_button == null and not action_btn.disabled:
			first_enabled_button = action_btn

	# The card that held keyboard/gamepad focus was just queue_free()'d and
	# replaced. Its actual deletion (and the focus-clear that comes with it)
	# happens on a LATER deferred flush than this one, so checking
	# gui_get_focus_owner() here still sees the stale old button and never
	# detects the loss. Since this only ever runs from a user interaction on
	# this screen, just unconditionally hand focus to the new equivalent button.
	var restored: Button = action_buttons_by_id.get(_last_interacted_upgrade_id, null)
	if restored == null or restored.disabled:
		restored = first_enabled_button
	if restored != null:
		# grab_focus() fires the same focus_entered hover-preview wiring a real
		# keyboard Tab-navigation would. When the just-equipped button is disabled,
		# `restored` falls back to a DIFFERENT, unequipped upgrade's button, so an
		# unguarded grab_focus() here would immediately preview-overwrite the ship
		# attach shape we just equipped with that other upgrade's (possibly
		# invisible, tier-0) shape. Suppress that one synthetic focus event only;
		# real Tab navigation elsewhere is untouched.
		_suppress_hover_preview = true
		restored.grab_focus()
		_suppress_hover_preview = false
	else:
		category_buttons[selected_category].grab_focus()

const CARD_STYLE_DEFAULT := {"bg": Color(0.08, 0.08, 0.14, 0.9), "border": Color(0.2, 0.25, 0.32, 1.0)}
const CARD_STYLE_EQUIPPED := {"bg": Color(0.07, 0.12, 0.16, 0.95), "border": Color(0.2, 0.8, 1.0, 1.0)}
const CARD_STYLE_PREVIEW := {"bg": Color(0.14, 0.12, 0.06, 0.95), "border": Color(1.0, 0.85, 0.3, 1.0)}

func _build_card(upgrade: UpgradeData, equipment: ShipEquipmentState) -> Control:
	var is_equipped: bool = equipment.equipped.get(upgrade.category, "") == upgrade.id
	var is_owned: bool = equipment.owned_upgrade_ids.has(upgrade.id)
	var mission_unlocked: bool = GameState.highest_unlocked >= upgrade.required_mission_id
	var can_afford: bool = GameState.credits >= upgrade.cost

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_card_stylebox(CARD_STYLE_EQUIPPED if is_equipped else CARD_STYLE_DEFAULT))
	card.mouse_entered.connect(_on_card_hover.bind(upgrade, card, true))
	card.mouse_exited.connect(_on_card_hover.bind(upgrade, card, false))

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", roundi(UiScale.px(2.0)))
	card.add_child(inner)

	inner.add_child(_build_upgrade_icon(upgrade))

	var name_lbl := Label.new()
	name_lbl.text = upgrade.display_name
	name_lbl.add_theme_font_size_override("font_size", UiScale.fs(16))
	inner.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = upgrade.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", UiScale.fs(12))
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	inner.add_child(desc_lbl)

	var action_btn := Button.new()
	action_btn.custom_minimum_size = UiScale.vec(Vector2(0, 44))
	action_btn.add_theme_font_size_override("font_size", UiScale.fs(14))
	if is_equipped:
		action_btn.text = "EQUIPPED"
		action_btn.disabled = true
		action_btn.add_theme_color_override("font_disabled_color", Color(0.2, 0.8, 1.0))
	elif is_owned:
		action_btn.text = "EQUIP"
		action_btn.disabled = false
		action_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	elif not ShipLoadoutRegistry.is_unlocked(_current_loadout()):
		action_btn.text = "SHIP LOCKED"
		action_btn.disabled = true
		action_btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	elif not mission_unlocked:
		action_btn.text = "NEED MISSION %d" % upgrade.required_mission_id
		action_btn.disabled = true
		action_btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	elif not can_afford:
		action_btn.text = "NOT ENOUGH CREDITS (%d)" % upgrade.cost
		action_btn.disabled = true
		action_btn.add_theme_color_override("font_disabled_color", Color(0.9, 0.3, 0.3))
	else:
		action_btn.text = "BUY (%d)" % upgrade.cost
		action_btn.disabled = false
		action_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))

	action_btn.pressed.connect(_try_equip.bind(upgrade))
	action_btn.focus_entered.connect(_on_card_hover.bind(upgrade, card, true))
	action_btn.focus_exited.connect(_on_card_hover.bind(upgrade, card, false))
	inner.add_child(action_btn)

	return card

const BASE_ICON_BOX_SIZE := Vector2(56, 56)
const ICON_SHAPE_SCALE := 2.2

func _build_upgrade_icon(upgrade: UpgradeData) -> Control:
	var box_size := UiScale.vec(BASE_ICON_BOX_SIZE)
	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = box_size
	icon_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_box.add_theme_stylebox_override("panel", _make_card_stylebox(CARD_STYLE_DEFAULT))
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_root := Node2D.new()
	icon_root.position = box_size * 0.5
	icon_box.add_child(icon_root)

	# Tier 0 has no hardware to show, so the card falls back to the flat
	# silhouette; higher tiers draw the same multi-part art bolted to the ship.
	var parts := ShipArt.get_attachment_parts(upgrade.category, upgrade.tier)
	var tint := UpgradeRegistry.get_category_color(upgrade.category)
	if parts.is_empty():
		var icon_shape := Polygon2D.new()
		icon_shape.polygon = upgrade.shape_points
		icon_shape.color = tint
		var shape_scale := ICON_SHAPE_SCALE * UiScale.factor()
		icon_shape.scale = Vector2(shape_scale, shape_scale)
		icon_root.add_child(icon_shape)
	else:
		icon_root.add_child(_build_attachment_icon_art(parts, tint, box_size))

	return icon_box

# Attachment art is authored around the hull, so an icon has to re-frame it:
# measure the parts' bounds, then centre and scale them to fill the icon box.
func _build_attachment_icon_art(parts: Array[Dictionary], tint: Color, box_size: Vector2) -> Node2D:
	var bounds := Rect2()
	var first := true
	for part in parts:
		for point in part["points"] as PackedVector2Array:
			if first:
				bounds = Rect2(point, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(point)

	var art := ShipArt.build_part_node(parts, tint)
	var span := maxf(maxf(bounds.size.x, bounds.size.y), 1.0)
	var fit := (box_size.x - UiScale.px(10.0)) / span
	art.scale = Vector2(fit, fit)
	art.position = -bounds.get_center() * fit
	return art

func _make_card_stylebox(style: Dictionary) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = style["bg"]
	box.border_color = style["border"]
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(roundi(UiScale.px(8.0)))
	return box

func _on_card_hover(upgrade: UpgradeData, card: PanelContainer, entered: bool) -> void:
	if _suppress_hover_preview:
		return
	var equipment := _current_equipment()
	var is_equipped: bool = equipment.equipped.get(upgrade.category, "") == upgrade.id

	if entered:
		card.add_theme_stylebox_override("panel", _make_card_stylebox(CARD_STYLE_PREVIEW))
		if not is_equipped:
			ship_display.preview_layer(upgrade.category, upgrade)
	else:
		card.add_theme_stylebox_override("panel", _make_card_stylebox(CARD_STYLE_EQUIPPED if is_equipped else CARD_STYLE_DEFAULT))
		ship_display.clear_preview(upgrade.category)

func _try_equip(upgrade: UpgradeData) -> void:
	_last_interacted_upgrade_id = upgrade.id

	if UpgradeRegistry.get_upgrade(upgrade.id) == null:
		return

	if GameState.highest_unlocked < upgrade.required_mission_id:
		return

	var equipment := _current_equipment()
	var already_owned := equipment.owned_upgrade_ids.has(upgrade.id)

	if not already_owned and not ShipLoadoutRegistry.is_unlocked(_current_loadout()):
		return

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
	if not unlocked:
		name_label.text = "%s  (LOCKED - complete Mission %d)" % [loadout.display_name, loadout.unlock_mission_id - 1]
		ship_display.modulate = Color(0.45, 0.45, 0.45)
	else:
		name_label.text = loadout.display_name
		ship_display.modulate = Color.WHITE
	credits_label.text = "CREDITS: %d" % GameState.credits
	prev_btn.disabled = index <= 0
	next_btn.disabled = index >= loadouts.size() - 1
	_update_select_ship_button()

func _update_select_ship_button() -> void:
	var loadout := _current_loadout()
	if GameState.selected_loadout_id == loadout.id:
		select_ship_button.text = "ACTIVE"
		select_ship_button.disabled = true
	elif not ShipLoadoutRegistry.is_unlocked(loadout):
		select_ship_button.text = "LOCKED"
		select_ship_button.disabled = true
	else:
		select_ship_button.text = "SELECT SHIP"
		select_ship_button.disabled = false

func _on_select_ship_pressed() -> void:
	AudioManager.play_menu_select()
	GameState.selected_loadout_id = _current_loadout().id
	SaveManager.save()
	_update_select_ship_button()

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
	SceneTransition.change_scene("res://src/ui/main_menu.tscn")
