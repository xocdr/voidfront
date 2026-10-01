extends Node2D

const PATCH_COUNT: int = 12
const REGION_SIZE: float = 2048.0

var patches: Array[Dictionary] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(get_instance_id()) + 42
	var palette := [
		Color(0.15, 0.05, 0.25, 0.08),
		Color(0.05, 0.1, 0.3, 0.06),
		Color(0.25, 0.05, 0.1, 0.07),
		Color(0.05, 0.2, 0.15, 0.05),
		Color(0.1, 0.05, 0.3, 0.06),
	]
	for i in range(PATCH_COUNT):
		patches.append({
			"pos": Vector2(rng.randf() * REGION_SIZE, rng.randf() * REGION_SIZE),
			"radius": rng.randf_range(150.0, 450.0),
			"color": palette[rng.randi() % palette.size()],
			"layers": rng.randi_range(2, 4),
		})
	queue_redraw()

func _draw() -> void:
	for patch in patches:
		var pos: Vector2 = patch.pos
		var base_radius: float = patch.radius
		var color: Color = patch.color
		var layer_count: int = patch.layers
		for l in range(layer_count, 0, -1):
			var t := float(l) / float(layer_count)
			var r := base_radius * t
			var c := Color(color.r, color.g, color.b, color.a * t * 0.7)
			_draw_soft_circle(pos, r, c)

func _draw_soft_circle(center: Vector2, radius: float, color: Color) -> void:
	var segments := 24
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in range(segments + 1):
		var angle := i * TAU / float(segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		colors.append(Color(color.r, color.g, color.b, 0.0))
	# Fan triangles from center
	for i in range(segments):
		var p0 := center
		var p1 := points[i]
		var p2 := points[i + 1]
		draw_polygon(
			PackedVector2Array([p0, p1, p2]),
			PackedColorArray([color, colors[i], colors[i + 1]])
		)
