# src/player/upgrade_data.gd
class_name UpgradeData
extends Resource

@export var id: String = ""
@export var category: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var tier: int = 0
@export var cost: int = 0
@export var required_mission_id: int = 1
@export var stat_modifiers: Dictionary = {}
