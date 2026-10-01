# src/player/ship_equipment_state.gd
class_name ShipEquipmentState
extends Resource

@export var ship_id: String = ""
@export var owned_upgrade_ids: Array[String] = []
@export var equipped: Dictionary = {}
