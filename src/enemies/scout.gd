extends BaseEnemy

var fly_through: bool = false
var fly_direction: Vector2 = Vector2.ZERO
var looping_back: bool = false
var loop_timer: float = 0.0

const FLY_THROUGH_DISTANCE: float = 80.0
const LOOP_BACK_TIME: float = 1.2
const TURN_SPEED: float = 3.0

# Visual variant data set by spawner or _ready
var variant_index: int = -1

const VARIANTS := [
	{ "color": Color(1.0, 0.3, 0.2), "shape": "diamond", "speed": 200.0, "hp": 30.0, "label": "Scout" },
	{ "color": Color(0.3, 1.0, 0.4), "shape": "arrow", "speed": 240.0, "hp": 20.0, "label": "Dart" },
	{ "color": Color(0.9, 0.8, 0.1), "shape": "chevron", "speed": 180.0, "hp": 40.0, "label": "Raider" },
	{ "color": Color(0.5, 0.4, 1.0), "shape": "tri", "speed": 220.0, "hp": 25.0, "label": "Phantom" },
]

func _ready() -> void:
	if variant_index < 0:
		variant_index = randi() % VARIANTS.size()
	var v: Dictionary = VARIANTS[variant_index]
	move_speed = v["speed"]
	contact_damage = 10.0

	# Set HP before super._ready() wires up health signals
	super._ready()
	health.max_hp = v["hp"]
	health.current_hp = v["hp"]

	_apply_variant_shape(v)

func _apply_variant_shape(v: Dictionary) -> void:
	var shape_node := get_node_or_null("Shape")
	if shape_node == null or not shape_node is Polygon2D:
		return
	shape_node.color = v["color"]
	match v["shape"]:
		"diamond":
			shape_node.polygon = PackedVector2Array([
				Vector2(0, -12), Vector2(12, 0), Vector2(0, 12), Vector2(-12, 0)
			])
		"arrow":
			shape_node.polygon = PackedVector2Array([
				Vector2(14, 0), Vector2(-10, -8), Vector2(-6, 0), Vector2(-10, 8)
			])
		"chevron":
			shape_node.polygon = PackedVector2Array([
				Vector2(12, 0), Vector2(-8, -10), Vector2(-4, 0), Vector2(-8, 10)
			])
		"tri":
			shape_node.polygon = PackedVector2Array([
				Vector2(12, 0), Vector2(-10, -9), Vector2(-10, 9)
			])

func move_toward_target() -> void:
	if target == null or not is_instance_valid(target):
		return

	if looping_back:
		loop_timer -= get_physics_process_delta_time()
		if loop_timer <= 0.0:
			looping_back = false
			fly_through = false
			# Resume approach
		else:
			# Curve back toward player
			var to_target := (target.global_position - global_position).normalized()
			var current_dir := Vector2.from_angle(rotation)
			var new_dir := current_dir.lerp(to_target, TURN_SPEED * get_physics_process_delta_time()).normalized()
			velocity = new_dir * move_speed
			rotation = new_dir.angle()
			_apply_velocity()
			return

	if not fly_through:
		var to_target := target.global_position - global_position
		if to_target.length() < FLY_THROUGH_DISTANCE:
			fly_through = true
			fly_direction = to_target.normalized()
			move_speed *= 1.3
		else:
			var direction := to_target.normalized()
			velocity = direction * move_speed
			rotation = direction.angle()
	else:
		velocity = fly_direction * move_speed
		rotation = fly_direction.angle()
		# After flying past, start loop-back
		var dist := global_position.distance_to(target.global_position)
		if dist > 400.0:
			looping_back = true
			loop_timer = LOOP_BACK_TIME
			move_speed /= 1.3

	_apply_velocity()
