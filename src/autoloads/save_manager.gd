# src/autoloads/save_manager.gd
extends Node

const SAVE_PATH := "user://save.json"
const TMP_PATH := "user://save.tmp"
const SAVE_VERSION := 1

func _ready() -> void:
	load_into_game_state()

func load_into_game_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("SaveManager: no save file found, writing defaults")
		_apply_payload(_build_default_payload())
		save()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: failed to open save file, falling back to defaults")
		_apply_payload(_build_default_payload())
		return

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: save file is not valid JSON, falling back to defaults")
		_apply_payload(_build_default_payload())
		return

	var payload: Dictionary = parsed
	if not payload.has("version") or payload["version"] != SAVE_VERSION:
		push_warning("SaveManager: unsupported save version '%s', falling back to defaults" % str(payload.get("version", "<missing>")))
		_apply_payload(_build_default_payload())
		return

	_apply_payload(payload)

func save() -> void:
	var payload := {
		"version": SAVE_VERSION,
		"credits": GameState.credits,
		"selected_loadout_id": GameState.selected_loadout_id,
		"highest_unlocked": GameState.highest_unlocked,
		"equipment": {},
	}
	for ship_id in GameState.equipment:
		var state: ShipEquipmentState = GameState.equipment[ship_id]
		payload["equipment"][ship_id] = {
			"owned": state.owned_upgrade_ids,
			"equipped": state.equipped,
		}

	var json_text := JSON.stringify(payload, "\t")

	var tmp_file := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if tmp_file == null:
		push_error("SaveManager: failed to open temp save file for writing")
		return
	tmp_file.store_string(json_text)
	tmp_file.close()

	var dir := DirAccess.open("user://")
	if dir == null or dir.rename(TMP_PATH, SAVE_PATH) != OK:
		push_error("SaveManager: failed to replace save file with temp file")

func _build_default_payload() -> Dictionary:
	var defaults := GameState._default_state()
	return {
		"version": SAVE_VERSION,
		"credits": defaults["credits"],
		"selected_loadout_id": defaults["selected_loadout_id"],
		"highest_unlocked": defaults["highest_unlocked"],
		"equipment": {},
	}

func _apply_payload(payload: Dictionary) -> void:
	GameState.credits = int(payload.get("credits", 0))
	GameState.highest_unlocked = int(payload.get("highest_unlocked", 1))

	var loadout_id: String = payload.get("selected_loadout_id", "interceptor")
	# ShipLoadoutRegistry.get_loadout() never returns null -- it falls back to
	# the interceptor loadout object when the id isn't found. Detect an invalid
	# id by comparing the returned loadout's own id against what was requested.
	var resolved_loadout := ShipLoadoutRegistry.get_loadout(loadout_id)
	if resolved_loadout == null or resolved_loadout.id != loadout_id:
		push_warning("SaveManager: selected_loadout_id '%s' not found, falling back to interceptor" % loadout_id)
		loadout_id = "interceptor"
	GameState.selected_loadout_id = loadout_id

	GameState.equipment = {}
	var equipment_payload: Dictionary = payload.get("equipment", {})
	for ship_id in equipment_payload:
		var raw: Dictionary = equipment_payload[ship_id]
		var state := ShipEquipmentState.new()
		state.ship_id = ship_id

		var validated_owned: Array[String] = []
		for upgrade_id in raw.get("owned", []):
			if UpgradeRegistry.get_upgrade(upgrade_id) != null:
				validated_owned.append(upgrade_id)
			else:
				push_warning("SaveManager: dropping unknown owned upgrade id '%s' for ship '%s'" % [upgrade_id, ship_id])
		state.owned_upgrade_ids = validated_owned

		var validated_equipped: Dictionary = {}
		var raw_equipped: Dictionary = raw.get("equipped", {})
		for category in UpgradeRegistry.get_categories():
			var candidate_id: String = raw_equipped.get(category, "")
			var candidate := UpgradeRegistry.get_upgrade(candidate_id) if not candidate_id.is_empty() else null
			var valid := candidate != null and candidate.category == category and validated_owned.has(candidate_id)
			if valid:
				validated_equipped[category] = candidate_id
			else:
				if not candidate_id.is_empty():
					push_warning("SaveManager: equipped[%s]='%s' invalid for ship '%s', falling back to starter" % [category, candidate_id, ship_id])
				validated_equipped[category] = UpgradeRegistry.get_starter_upgrade(category).id
				if not validated_owned.has(validated_equipped[category]):
					validated_owned.append(validated_equipped[category])
		state.owned_upgrade_ids = validated_owned
		state.equipped = validated_equipped

		GameState.equipment[ship_id] = state
