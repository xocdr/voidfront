class_name AlliedTransport
extends CharacterBody2D

var waypoints: Array[Vector2] = []
var current_waypoint: int = 0
var move_speed: float = 50.0
var is_alive: bool = true

@onready var health: HealthComponent = $HealthComponent

signal transport_destroyed

func _ready() -> void:
	add_to_group("allies")
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	var trail := EngineTrail.create(Color(0.2, 1.0, 0.4, 0.5), 0.8)
	add_child(trail)

func initialize(path_points: Array[Vector2]) -> void:
	waypoints = path_points
	if waypoints.size() > 0:
		global_position = waypoints[0]
		current_waypoint = 1

func _physics_process(_delta: float) -> void:
	if not is_alive or waypoints.is_empty():
		return

	if current_waypoint >= waypoints.size():
		# Loop back to start
		current_waypoint = 0

	var target_pos := waypoints[current_waypoint]
	var to_target := target_pos - global_position
	var dist := to_target.length()

	if dist < 20.0:
		current_waypoint += 1
		return

	var direction := to_target.normalized()
	velocity = direction * move_speed
	rotation = direction.angle()
	move_and_slide()

func _on_damaged(_amount: float) -> void:
	var shape_node := get_node_or_null("Shape")
	if shape_node and shape_node is Polygon2D:
		var original: Color = shape_node.color
		shape_node.color = Color.WHITE
		get_tree().create_timer(0.05).timeout.connect(func():
			if is_instance_valid(shape_node):
				shape_node.color = original
		)

func _on_died() -> void:
	is_alive = false
	ExplosionEffect.spawn(get_tree().root, global_position, 2.0)
	AudioManager.play_explosion()
	transport_destroyed.emit()
	queue_free()
