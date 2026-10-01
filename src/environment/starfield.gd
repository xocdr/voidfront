extends Node2D

const REGION_SIZE: float = 2048.0

var stars: PackedVector2Array
var star_sizes: PackedFloat32Array
var star_colors: PackedColorArray
var seed_value: int = 0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else hash(get_instance_id())
	var count := 120 + seed_value * 30
	for i in range(count):
		stars.append(Vector2(rng.randf() * REGION_SIZE, rng.randf() * REGION_SIZE))
		var base_size := rng.randf_range(0.4, 1.8)
		if seed_value >= 3:
			base_size = rng.randf_range(0.8, 2.5)
		star_sizes.append(base_size)
		var b := rng.randf_range(0.3, 1.0)
		var tint_r := b + rng.randf_range(-0.05, 0.08)
		var tint_b := b + rng.randf_range(0.0, 0.12)
		star_colors.append(Color(tint_r, b, tint_b, clampf(b * 0.9, 0.2, 1.0)))
	queue_redraw()

func _draw() -> void:
	for i in range(stars.size()):
		draw_circle(stars[i], star_sizes[i], star_colors[i])
