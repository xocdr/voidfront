class_name MissionData
extends Resource

@export var id: int = 1
@export var mission_name: String = ""
@export var briefing_text: Array[String] = []
@export var objectives: Array[ObjectiveData] = []
@export var waves: Array[WaveData] = []
@export var arena_radius: float = 3000.0
@export var completion_briefing: Array[String] = []
@export var background_intensity: float = 1.0
@export var transport_waypoints: Array[Vector2] = []
@export var obstacle_positions: Array[Vector2] = []
@export var continuous_spawn_after_waves: bool = false
