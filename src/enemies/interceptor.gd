extends BaseEnemy

var strafe_angle: float = 0.0
var strafe_dir: int = 1
var fire_timer: float = 0.0
var projectile_scene: PackedScene = preload("res://src/projectiles/enemy_projectile.tscn")

const ENGAGE_DISTANCE: float = 350.0
const FIRE_INTERVAL: float = 1.2
const STRAFE_SPEED: float = 1.8

func _ready() -> void:
	move_speed = 260.0
	contact_damage = 15.0
	strafe_dir = 1 if randf() > 0.5 else -1
	super._ready()
	health.max_hp = 50.0
	health.current_hp = 50.0
	_apply_shape()

func _apply_shape() -> void:
	var shape_node := get_node_or_null("Shape")
	if shape_node and shape_node is Polygon2D:
		shape_node.color = Color(1.0, 0.6, 0.1)
		shape_node.polygon = PackedVector2Array([
			Vector2(14, 0), Vector2(-6, -12), Vector2(-2, -4),
			Vector2(-10, 0), Vector2(-2, 4), Vector2(-6, 12)
		])

func move_toward_target() -> void:
	if target == null or not is_instance_valid(target):
		return

	var to_target := target.global_position - global_position
	var dist := to_target.length()
	var delta := get_physics_process_delta_time()

	if dist > ENGAGE_DISTANCE:
		# Close in at an offset angle
		var approach := to_target.normalized().rotated(0.3 * strafe_dir)
		velocity = approach * move_speed
	else:
		# Strafe around target
		strafe_angle += STRAFE_SPEED * delta * strafe_dir
		var orbit_pos := target.global_position + Vector2(cos(strafe_angle), sin(strafe_angle)) * ENGAGE_DISTANCE
		var to_orbit := (orbit_pos - global_position).normalized()
		velocity = to_orbit * move_speed * 0.8

	rotation = to_target.angle()
	_apply_velocity()

	# Fire at player
	fire_timer -= delta
	if fire_timer <= 0.0 and dist < 500.0:
		fire_timer = FIRE_INTERVAL + randf_range(-0.2, 0.2)
		_fire()

func _fire() -> void:
	if not is_instance_valid(target):
		return
	var proj := projectile_scene.instantiate()
	proj.global_position = global_position
	proj.rotation = (target.global_position - global_position).angle()
	proj.set_meta("enemy_projectile", true)
	get_tree().root.add_child(proj)
	AudioManager.play_laser()
