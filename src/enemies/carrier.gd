extends BaseEnemy

var spawn_timer: float = 0.0
var scout_scene: PackedScene = preload("res://src/enemies/scout.tscn")
var spawned_count: int = 0

const HOLD_DISTANCE: float = 700.0
const SPAWN_INTERVAL: float = 5.0
const MAX_SPAWNS: int = 12
const DRIFT_SPEED: float = 40.0

func _ready() -> void:
	move_speed = 60.0
	contact_damage = 25.0
	despawn_distance = 3000.0
	super._ready()
	health.max_hp = 200.0
	health.current_hp = 200.0
	_apply_shape()
	spawn_timer = 2.0

func _apply_shape() -> void:
	var shape_node := get_node_or_null("Shape")
	if shape_node and shape_node is Polygon2D:
		shape_node.color = Color(0.6, 0.15, 0.15)
		shape_node.polygon = PackedVector2Array([
			Vector2(20, 0), Vector2(10, -16), Vector2(-8, -18),
			Vector2(-20, -8), Vector2(-20, 8), Vector2(-8, 18),
			Vector2(10, 16)
		])

func move_toward_target() -> void:
	if target == null or not is_instance_valid(target):
		return

	var to_target := target.global_position - global_position
	var dist := to_target.length()
	var delta := get_physics_process_delta_time()

	if dist > HOLD_DISTANCE + 100.0:
		# Slowly approach
		velocity = to_target.normalized() * move_speed
	elif dist < HOLD_DISTANCE - 100.0:
		# Back off
		velocity = -to_target.normalized() * DRIFT_SPEED
	else:
		# Drift sideways
		var perp := to_target.normalized().rotated(PI * 0.5)
		velocity = perp * DRIFT_SPEED

	rotation = to_target.angle()
	_apply_velocity()

	# Spawn scouts
	spawn_timer -= delta
	if spawn_timer <= 0.0 and spawned_count < MAX_SPAWNS:
		spawn_timer = SPAWN_INTERVAL
		_spawn_scout()

func _spawn_scout() -> void:
	var scout := scout_scene.instantiate()
	var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
	scout.global_position = global_position + offset
	scout.target = target
	var container := get_parent()
	if container:
		container.add_child(scout)
	spawned_count += 1
