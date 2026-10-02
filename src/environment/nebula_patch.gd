extends Node2D

var blobs: Array[Dictionary] = []
var color: Color
var core_color: Color
var radius: float

const SEGMENTS := 12

# The whole patch is one mesh, built once. Drawing it as ~100 separate
# draw_polygon() triangles per patch (times every mirrored parallax tile) was a
# large part of the per-frame cost on phones.
var _mesh: ArrayMesh

func _ready() -> void:
	_mesh = _build_mesh()
	queue_redraw()

func _draw() -> void:
	if _mesh:
		draw_mesh(_mesh, null)

func _build_mesh() -> ArrayMesh:
	var verts := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	for blob in blobs:
		var blob_pos: Vector2 = blob.offset
		var base_radius: float = blob.radius
		var layer_count: int = blob.layers
		for l in range(layer_count, 0, -1):
			var t := float(l) / float(layer_count)
			var c := Color(color.r, color.g, color.b, color.a * t * 0.7)
			_add_soft_circle(verts, colors, indices, blob_pos, base_radius * t, c)

	_add_soft_circle(verts, colors, indices, Vector2.ZERO, radius * 0.25, core_color)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# Triangle fan: opaque-ish centre fading to transparent at the rim.
func _add_soft_circle(verts: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array, center: Vector2, radius_val: float, color_val: Color) -> void:
	var base := verts.size()
	verts.append(center)
	colors.append(color_val)
	for i in range(SEGMENTS):
		var angle := i * TAU / float(SEGMENTS)
		verts.append(center + Vector2(cos(angle), sin(angle)) * radius_val)
		colors.append(Color(color_val.r, color_val.g, color_val.b, 0.0))
	for i in range(SEGMENTS):
		indices.append(base)
		indices.append(base + 1 + i)
		indices.append(base + 1 + (i + 1) % SEGMENTS)
