extends Node2D

var player: Node2D
var spawn_timer: float = 0.0
var spawn_interval: float = 1.2
var intensity: float = 1.0
var ships: Array[Node2D] = []

const MAX_SHIPS: int = 8
const CLEANUP_INTERVAL: float = 0.25

# Ship with its velocity stored directly, instead of get_meta() lookups per frame.
class TrafficShip extends Node2D:
	var dir: Vector2 = Vector2.RIGHT
	var spd: float = 0.0

var _cleanup_timer: float = 0.0
const SPAWN_DISTANCE: float = 1200.0
const DESPAWN_DISTANCE: float = 1500.0

var ship_configs := [
	{"size": 3.0, "speed": 80.0, "color": Color(0.4, 0.5, 0.6, 0.4), "type": "fighter"},
	{"size": 4.0, "speed": 60.0, "color": Color(0.5, 0.4, 0.3, 0.35), "type": "fighter"},
	{"size": 6.0, "speed": 40.0, "color": Color(0.3, 0.4, 0.5, 0.3), "type": "cruiser"},
	{"size": 2.5, "speed": 100.0, "color": Color(0.6, 0.3, 0.3, 0.4), "type": "fighter"},
]

func initialize(p_player: Node2D, p_intensity: float = 1.0) -> void:
	player = p_player
	intensity = p_intensity
	spawn_interval = 1.5 / maxf(intensity, 0.3)

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	spawn_timer -= delta
	if spawn_timer <= 0.0 and ships.size() < MAX_SHIPS:
		spawn_timer = spawn_interval * randf_range(0.6, 1.4)
		_spawn_ship()

	# Clean up distant ships (a few times a second is plenty)
	_cleanup_timer -= delta
	if _cleanup_timer > 0.0:
		return
	_cleanup_timer = CLEANUP_INTERVAL
	var despawn_sq := DESPAWN_DISTANCE * DESPAWN_DISTANCE
	for i in range(ships.size() - 1, -1, -1):
		if not is_instance_valid(ships[i]):
			ships.remove_at(i)
			continue
		if ships[i].global_position.distance_squared_to(player.global_position) > despawn_sq:
			ships[i].queue_free()
			ships.remove_at(i)

func _spawn_ship() -> void:
	var config: Dictionary = ship_configs[randi() % ship_configs.size()]
	var ship := TrafficShip.new()

	var angle := randf() * TAU
	var start_pos := player.global_position + Vector2(cos(angle), sin(angle)) * SPAWN_DISTANCE

	# Direction: mostly across the screen, not directly at player
	var cross_angle := angle + PI * 0.5 + randf_range(-0.4, 0.4)
	var direction := Vector2(cos(cross_angle), sin(cross_angle))

	ship.global_position = start_pos
	ship.rotation = direction.angle()

	var body := _create_ship_shape(config)
	ship.add_child(body)

	# Dim engine glow, tinted warmer/brighter than the hull for a glowing-thruster feel
	var trail := CPUParticles2D.new()
	trail.emitting = true
	trail.amount = 3
	trail.lifetime = 0.3
	trail.local_coords = false
	trail.direction = Vector2(-1, 0)
	trail.spread = 10.0
	trail.initial_velocity_min = 10.0
	trail.initial_velocity_max = 25.0
	trail.gravity = Vector2.ZERO
	trail.scale_amount_min = 1.0 * config.size * 0.3
	trail.scale_amount_max = 2.0 * config.size * 0.3
	trail.color = Color(minf(config.color.r + 0.4, 1.0), minf(config.color.g + 0.25, 1.0), minf(config.color.b + 0.5, 1.0), 0.22)
	trail.position = Vector2(-config.size * 2, 0)
	ship.add_child(trail)

	if config.type == "cruiser":
		_add_running_lights(ship, config)

	ship.spd = config.speed * randf_range(0.7, 1.3)
	ship.dir = direction

	add_child(ship)
	ships.append(ship)

	# Occasionally spawn a distant laser bolt between traffic ships
	if randf() < 0.3 and ships.size() > 1:
		_spawn_distant_bolt(ship)

func _create_ship_shape(config: Dictionary) -> Polygon2D:
	var poly := Polygon2D.new()
	var s: float = config.size
	if config.type == "cruiser":
		poly.polygon = PackedVector2Array([
			Vector2(-s * 2, -s * 0.6), Vector2(s * 2, 0),
			Vector2(-s * 2, s * 0.6), Vector2(-s * 1.5, 0),
		])
	else:
		poly.polygon = PackedVector2Array([
			Vector2(-s, -s * 0.5), Vector2(s * 1.5, 0), Vector2(-s, s * 0.5),
		])
	poly.color = config.color
	return poly

func _add_running_lights(ship: Node2D, config: Dictionary) -> void:
	var s: float = config.size
	var light_offsets := [Vector2(-s * 1.6, -s * 0.5), Vector2(-s * 1.6, s * 0.5)]
	var light_colors := [Color(1.0, 0.25, 0.2, 0.9), Color(0.2, 0.8, 1.0, 0.9)]
	for i in range(light_offsets.size()):
		var light := Polygon2D.new()
		var r := maxf(s * 0.18, 0.5)
		light.polygon = PackedVector2Array([
			Vector2(-r, 0), Vector2(0, -r), Vector2(r, 0), Vector2(0, r),
		])
		light.position = light_offsets[i]
		light.color = light_colors[i]
		ship.add_child(light)

		var tween := create_tween()
		tween.set_loops()
		tween.tween_interval(randf_range(0.6, 1.4))
		tween.tween_property(light, "modulate:a", 0.15, 0.12)
		tween.tween_property(light, "modulate:a", 1.0, 0.12)

func _spawn_distant_bolt(source_ship: Node2D) -> void:
	var bolt := Line2D.new()
	bolt.width = 1.0
	var bolt_color := Color(randf_range(0.5, 1.0), randf_range(0.3, 0.8), randf_range(0.2, 0.5), 0.5)
	bolt.default_color = bolt_color
	var dir := Vector2(cos(source_ship.rotation), sin(source_ship.rotation))
	bolt.add_point(Vector2.ZERO)
	bolt.add_point(dir * randf_range(30, 80))
	bolt.global_position = source_ship.global_position + dir * 10
	add_child(bolt)
	var tween := create_tween()
	tween.tween_property(bolt, "position", bolt.position + dir * 200, 0.4)
	tween.parallel().tween_property(bolt, "modulate", Color(1, 1, 1, 0), 0.4)
	tween.tween_callback(bolt.queue_free)

func _physics_process(delta: float) -> void:
	for ship in ships:
		if is_instance_valid(ship):
			(ship as TrafficShip).position += (ship as TrafficShip).dir * (ship as TrafficShip).spd * delta
