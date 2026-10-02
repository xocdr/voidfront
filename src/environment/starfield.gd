extends Node2D

const REGION_SIZE: float = 2048.0
const FLARE_COUNT: int = 5
const SHOOTING_STAR_MIN_INTERVAL: float = 4.0
const SHOOTING_STAR_MAX_INTERVAL: float = 9.0
const TWINKLE_FRACTION: float = 0.3
const REDRAW_INTERVAL: float = 1.0 / 20.0

var stars: PackedVector2Array
var star_sizes: PackedFloat32Array
var star_colors: PackedColorArray
var seed_value: int = 0

var twinkle_enabled: bool = false
var twinkle_indices: PackedInt32Array
var twinkle_phases: PackedFloat32Array
var twinkle_speeds: PackedFloat32Array
var redraw_accum: float = 0.0

var flare_indices: Array[int] = []

var shooting_stars_enabled: bool = false
var shooting_star_timer: float = 0.0
var shooting_stars: Array[Dictionary] = []

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
		if rng.randf() < 0.08:
			# Occasional warm (orange/red) star for color variety.
			tint_r = clampf(b + rng.randf_range(0.1, 0.25), 0.0, 1.0)
			tint_b = clampf(b - rng.randf_range(0.1, 0.25), 0.0, 1.0)
		star_colors.append(Color(tint_r, b, tint_b, clampf(b * 0.9, 0.2, 1.0)))

	twinkle_enabled = seed_value == 3
	if twinkle_enabled:
		for i in range(count):
			if rng.randf() < TWINKLE_FRACTION:
				twinkle_indices.append(i)
				twinkle_phases.append(rng.randf_range(0.0, TAU))
				twinkle_speeds.append(rng.randf_range(1.2, 3.0))

	# Biggest stars in the layer get a small cross-flare glow.
	var sorted_indices := range(count)
	sorted_indices.sort_custom(func(a, b): return star_sizes[a] > star_sizes[b])
	for i in range(mini(FLARE_COUNT, sorted_indices.size())):
		flare_indices.append(sorted_indices[i])

	shooting_stars_enabled = seed_value == 1
	if shooting_stars_enabled:
		shooting_star_timer = rng.randf_range(SHOOTING_STAR_MIN_INTERVAL, SHOOTING_STAR_MAX_INTERVAL)

	queue_redraw()

func _process(delta: float) -> void:
	var needs_redraw := false

	if twinkle_enabled:
		redraw_accum += delta
		if redraw_accum >= REDRAW_INTERVAL:
			for i in range(twinkle_indices.size()):
				twinkle_phases[i] += redraw_accum * twinkle_speeds[i]
			redraw_accum = 0.0
			needs_redraw = true

	if shooting_stars_enabled:
		shooting_star_timer -= delta
		if shooting_star_timer <= 0.0:
			shooting_star_timer = randf_range(SHOOTING_STAR_MIN_INTERVAL, SHOOTING_STAR_MAX_INTERVAL)
			_spawn_shooting_star()
		if not shooting_stars.is_empty():
			for i in range(shooting_stars.size() - 1, -1, -1):
				var s: Dictionary = shooting_stars[i]
				s.life -= delta
				s.pos += s.vel * delta
				if s.life <= 0.0:
					shooting_stars.remove_at(i)
				else:
					shooting_stars[i] = s
			needs_redraw = true

	if needs_redraw:
		queue_redraw()

func _spawn_shooting_star() -> void:
	var angle := randf_range(PI * 0.15, PI * 0.45)
	var speed := randf_range(900.0, 1400.0)
	var start := Vector2(randf_range(0.0, REGION_SIZE), randf_range(-100.0, REGION_SIZE * 0.4))
	shooting_stars.append({
		"pos": start,
		"vel": Vector2(cos(angle), sin(angle)) * speed,
		"life": 0.6,
		"max_life": 0.6,
	})

func _draw() -> void:
	for i in range(stars.size()):
		_draw_star(stars[i], star_sizes[i], star_colors[i])

	for t in range(twinkle_indices.size()):
		var idx := twinkle_indices[t]
		var color: Color = star_colors[idx]
		var pulse := 0.65 + 0.35 * sin(twinkle_phases[t])
		var twinkled := Color(color.r, color.g, color.b, clampf(color.a * pulse, 0.0, 1.0))
		_draw_star(stars[idx], star_sizes[idx], twinkled)

	for idx in flare_indices:
		_draw_flare(stars[idx], star_sizes[idx], star_colors[idx])

	for s in shooting_stars:
		_draw_shooting_star(s)

func _draw_flare(pos: Vector2, size: float, color: Color) -> void:
	var glow := Color(color.r, color.g, color.b, color.a * 0.5)
	var length := size * 5.0
	draw_line(pos - Vector2(length, 0), pos + Vector2(length, 0), glow, size * 0.4)
	draw_line(pos - Vector2(0, length), pos + Vector2(0, length), glow, size * 0.4)

func _draw_shooting_star(s: Dictionary) -> void:
	var fade: float = clampf(s.life / s.max_life, 0.0, 1.0)
	var tail: Vector2 = s.vel.normalized() * -60.0
	draw_line(s.pos, s.pos + tail, Color(1.0, 1.0, 0.95, fade * 0.8), 1.5)
	_draw_star(s.pos, 1.6, Color(1.0, 1.0, 0.95, fade))

# Stars are at most a couple of pixels across, so a square reads the same as a
# circle. draw_circle() builds a 64-sided fan per star, which across several
# parallax layers and their mirrored tiles was hundreds of thousands of
# triangles per frame.
func _draw_star(pos: Vector2, size: float, color: Color) -> void:
	draw_rect(Rect2(pos.x - size, pos.y - size, size * 2.0, size * 2.0), color)
