extends Node2D

const PATCH_COUNT: int = 12
const REGION_SIZE: float = 2048.0
const BLOBS_PER_PATCH_MIN: int = 3
const BLOBS_PER_PATCH_MAX: int = 4

var NebulaPatchScript: GDScript = preload("res://src/environment/nebula_patch.gd")

var patch_nodes: Array[Node2D] = []
var base_positions: PackedVector2Array
var drift_speeds: PackedFloat32Array
var drift_phases: PackedFloat32Array
var time_elapsed: float = 0.0

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
	var core_palette := [
		Color(0.55, 0.3, 0.75, 0.16),
		Color(0.3, 0.45, 0.85, 0.14),
		Color(0.75, 0.3, 0.35, 0.15),
		Color(0.3, 0.7, 0.55, 0.12),
		Color(0.45, 0.3, 0.85, 0.14),
	]
	for i in range(PATCH_COUNT):
		var palette_idx := rng.randi() % palette.size()
		var center := Vector2(rng.randf() * REGION_SIZE, rng.randf() * REGION_SIZE)
		var base_radius := rng.randf_range(150.0, 450.0)
		var blobs: Array[Dictionary] = []
		var blob_count := rng.randi_range(BLOBS_PER_PATCH_MIN, BLOBS_PER_PATCH_MAX)
		for b in range(blob_count):
			blobs.append({
				"offset": Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * base_radius * 0.5,
				"radius": base_radius * rng.randf_range(0.45, 0.85),
				"layers": rng.randi_range(2, 3),
			})

		var patch := Node2D.new()
		patch.set_script(NebulaPatchScript)
		patch.position = center
		patch.blobs = blobs
		patch.color = palette[palette_idx]
		patch.core_color = core_palette[palette_idx]
		patch.radius = base_radius
		add_child(patch)

		patch_nodes.append(patch)
		base_positions.append(center)
		drift_speeds.append(rng.randf_range(0.015, 0.04) * (1.0 if rng.randf() < 0.5 else -1.0))
		drift_phases.append(rng.randf_range(0.0, TAU))

func _process(delta: float) -> void:
	time_elapsed += delta
	# Cheap: only moves already-drawn patch nodes, never triggers a redraw.
	for i in range(patch_nodes.size()):
		var drift := sin(time_elapsed * drift_speeds[i] + drift_phases[i]) * 12.0
		patch_nodes[i].position = base_positions[i] + Vector2(drift, drift * 0.6)
