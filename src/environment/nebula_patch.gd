extends Node2D

var blobs: Array[Dictionary] = []
var color: Color
var core_color: Color
var radius: float

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	for blob in blobs:
		var blob_pos: Vector2 = blob.offset
		var base_radius: float = blob.radius
		var layer_count: int = blob.layers
		for l in range(layer_count, 0, -1):
			var t := float(l) / float(layer_count)
			var r := base_radius * t
			var c := Color(color.r, color.g, color.b, color.a * t * 0.7)
			_draw_soft_circle(blob_pos, r, c)

	_draw_soft_circle(Vector2.ZERO, radius * 0.25, core_color)

func _draw_soft_circle(center: Vector2, radius_val: float, color_val: Color) -> void:
	const SEGMENTS := 12
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in range(SEGMENTS + 1):
		var angle := i * TAU / float(SEGMENTS)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius_val)
		colors.append(Color(color_val.r, color_val.g, color_val.b, 0.0))
	for i in range(SEGMENTS):
		var p0 := center
		var p1 := points[i]
		var p2 := points[i + 1]
		draw_polygon(
			PackedVector2Array([p0, p1, p2]),
			PackedColorArray([color_val, colors[i], colors[i + 1]])
		)
