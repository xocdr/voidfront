extends BaseEnemy

var fire_timer: float = 0.0
var ally_target: Node2D
var projectile_scene: PackedScene = preload("res://src/projectiles/enemy_projectile.tscn")

const FIRE_INTERVAL: float = 2.0
const FIRE_RANGE: float = 600.0
const ATTACK_DAMAGE: float = 15.0

func _ready() -> void:
	move_speed = 120.0
	contact_damage = 20.0
	super._ready()
	health.max_hp = 100.0
	health.current_hp = 100.0
	_apply_shape()

func _apply_shape() -> void:
	var shape_node := get_node_or_null("Shape")
	if shape_node and shape_node is Polygon2D:
		shape_node.color = Color(0.8, 0.2, 0.8)
		shape_node.polygon = PackedVector2Array([
			Vector2(16, 0), Vector2(4, -14), Vector2(-12, -10),
			Vector2(-16, 0), Vector2(-12, 10), Vector2(4, 14)
		])

func _find_ally_target() -> void:
	var allies := get_tree().get_nodes_in_group("allies")
	if allies.size() > 0:
		ally_target = allies[0]

func move_toward_target() -> void:
	# Prefer targeting allies over player
	if ally_target == null or not is_instance_valid(ally_target):
		_find_ally_target()

	var move_target: Node2D = ally_target if (ally_target and is_instance_valid(ally_target)) else target
	if move_target == null or not is_instance_valid(move_target):
		return

	var to_target := move_target.global_position - global_position
	var dist := to_target.length()
	var delta := get_physics_process_delta_time()

	var direction := to_target.normalized()
	velocity = direction * move_speed
	rotation = direction.angle()
	move_and_slide()

	# Fire at target
	fire_timer -= delta
	if fire_timer <= 0.0 and dist < FIRE_RANGE:
		fire_timer = FIRE_INTERVAL + randf_range(-0.3, 0.3)
		_fire(move_target)

func _fire(fire_target: Node2D) -> void:
	if not is_instance_valid(fire_target):
		return
	var proj := projectile_scene.instantiate()
	proj.global_position = global_position
	proj.rotation = (fire_target.global_position - global_position).angle()
	proj.damage = ATTACK_DAMAGE
	get_tree().root.add_child(proj)
	AudioManager.play_laser()
