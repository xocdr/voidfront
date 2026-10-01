extends Node

var kills: int = 0
var shots_fired: int = 0
var shots_hit: int = 0
var damage_taken: float = 0.0
var mission_time: float = 0.0
var is_mission_active: bool = false

var current_mission_id: int = 1
var highest_unlocked: int = 1
var selected_loadout_id: String = "interceptor"
var credits: int = 0
var equipment: Dictionary = {}

signal enemy_killed
signal player_damaged(amount: float)
signal player_died

func reset_stats() -> void:
	kills = 0
	shots_fired = 0
	shots_hit = 0
	damage_taken = 0.0
	mission_time = 0.0
	is_mission_active = false

func _default_state() -> Dictionary:
	return {
		"credits": 0,
		"selected_loadout_id": "interceptor",
		"highest_unlocked": 1,
	}

func _default_equipment_for(ship_id: String) -> ShipEquipmentState:
	var state := ShipEquipmentState.new()
	state.ship_id = ship_id
	state.owned_upgrade_ids = []
	state.equipped = {}
	for category in UpgradeRegistry.get_categories():
		var starter := UpgradeRegistry.get_starter_upgrade(category)
		state.owned_upgrade_ids.append(starter.id)
		state.equipped[category] = starter.id
	return state

func get_equipment_for(ship_id: String) -> ShipEquipmentState:
	if not equipment.has(ship_id):
		equipment[ship_id] = _default_equipment_for(ship_id)
	return equipment[ship_id]

func record_kill() -> void:
	kills += 1
	enemy_killed.emit()

func record_shot() -> void:
	shots_fired += 1

func record_hit() -> void:
	shots_hit += 1

func get_accuracy() -> float:
	if shots_fired == 0:
		return 0.0
	return float(shots_hit) / float(shots_fired) * 100.0

func complete_mission(mission_id: int) -> void:
	if mission_id >= highest_unlocked:
		highest_unlocked = mini(mission_id + 1, MissionRegistry.get_mission_count())
	credits += 500
	SaveManager.save()
