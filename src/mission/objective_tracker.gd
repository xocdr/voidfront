class_name ObjectiveTracker
extends Node

var objectives: Array[ObjectiveData] = []
var is_complete: bool = false
var is_failed: bool = false
var ally_alive: bool = true

signal mission_complete
signal mission_failed
signal objective_updated(index: int, current: float, target: float)

func initialize(p_objectives: Array[ObjectiveData]) -> void:
	objectives = p_objectives
	GameState.enemy_killed.connect(_on_enemy_killed)
	GameState.player_died.connect(_on_player_died)

func notify_ally_destroyed() -> void:
	ally_alive = false
	for obj in objectives:
		if obj.type == ObjectiveData.Type.PROTECT_ALLY:
			is_failed = true
			mission_failed.emit()
			return

func _process(_delta: float) -> void:
	if is_complete or is_failed:
		return
	_check_objectives()

func _check_objectives() -> void:
	if is_complete or is_failed:
		return
	var all_met := true
	for i in range(objectives.size()):
		var obj := objectives[i]
		var current := _get_current_value(obj)
		objective_updated.emit(i, current, obj.target_value)
		if obj.type == ObjectiveData.Type.PROTECT_ALLY:
			if not ally_alive:
				return
		elif current < obj.target_value:
			all_met = false

	if all_met and objectives.size() > 0:
		is_complete = true
		mission_complete.emit()

func _get_current_value(obj: ObjectiveData) -> float:
	match obj.type:
		ObjectiveData.Type.DESTROY_COUNT:
			return float(GameState.kills)
		ObjectiveData.Type.SURVIVE_TIME:
			return GameState.mission_time
		ObjectiveData.Type.PROTECT_ALLY:
			return 1.0 if ally_alive else 0.0
	return 0.0

func get_objective_progress(index: int) -> Dictionary:
	if index < 0 or index >= objectives.size():
		return {}
	var obj := objectives[index]
	var current := _get_current_value(obj)
	return {"current": current, "target": obj.target_value, "met": current >= obj.target_value}

func _on_enemy_killed() -> void:
	_check_objectives()

func _on_player_died() -> void:
	if not is_complete:
		is_failed = true
		mission_failed.emit()
