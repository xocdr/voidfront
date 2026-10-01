class_name ShipLoadoutData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var unlock_mission_id: int = 1

@export var move_speed: float = 400.0
@export var fire_cooldown: float = 0.12
@export var special_cooldown_time: float = 8.0
@export var special_radius: float = 200.0
@export var special_damage: float = 50.0
@export var max_hp: float = 100.0

@export var color: Color = Color(0.2, 0.8, 1.0)
@export var polygon_points: PackedVector2Array = PackedVector2Array([Vector2(-12, -10), Vector2(16, 0), Vector2(-12, 10)])
