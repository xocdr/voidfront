class_name HyperspeedTransition
extends CanvasLayer

signal transition_midpoint
signal transition_finished

const STAR_COUNT: int = 120
const WIND_UP_TIME: float = 0.8
const STREAK_TIME: float = 0.6
const COOL_DOWN_TIME: float = 0.5

var stars: Array[Dictionary] = []
var phase: int = 0
var phase_timer: float = 0.0
var streak_intensity: float = 0.0
var flash_alpha: float = 0.0
var canvas: Control
var flash_rect: ColorRect

func _ready() -> void:
	layer = 95

	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.draw.connect(_draw_effect)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(0.8, 0.9, 1.0, 0.0)
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)

	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in range(STAR_COUNT):
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(20, 500)
		stars.append({
			"angle": angle,
			"base_dist": dist,
			"brightness": rng.randf_range(0.4, 1.0),
			"size": rng.randf_range(0.8, 2.5),
		})

func play() -> void:
	phase = 1
	phase_timer = 0.0
	streak_intensity = 0.0

func _process(delta: float) -> void:
	if phase == 0:
		return

	phase_timer += delta

	match phase:
		1:
			streak_intensity = (phase_timer / WIND_UP_TIME) * 0.3
			if phase_timer >= WIND_UP_TIME:
				phase = 2
				phase_timer = 0.0
				AudioManager.play_special()
		2:
			streak_intensity = 0.3 + (phase_timer / STREAK_TIME) * 0.7
			if phase_timer >= STREAK_TIME:
				phase = 3
				phase_timer = 0.0
				flash_alpha = 1.0
				transition_midpoint.emit()
		3:
			flash_alpha = 1.0 - phase_timer * 3.0
			if flash_alpha <= 0.0:
				flash_alpha = 0.0
				phase = 4
				phase_timer = 0.0
		4:
			streak_intensity = 1.0 - (phase_timer / COOL_DOWN_TIME)
			if phase_timer >= COOL_DOWN_TIME:
				phase = 0
				streak_intensity = 0.0
				transition_finished.emit()
				queue_free()
				return

	flash_rect.color.a = clampf(flash_alpha, 0.0, 1.0)
	canvas.queue_redraw()

func _draw_effect() -> void:
	if phase == 0:
		return

	var center := canvas.size * 0.5
	for star in stars:
		var angle: float = star["angle"]
		var base_dist: float = star["base_dist"]
		var brightness: float = star["brightness"]
		var sz: float = star["size"]

		var dir := Vector2(cos(angle), sin(angle))
		var start_pos := center + dir * base_dist

		var streak_len := streak_intensity * base_dist * 1.5
		var end_pos := start_pos + dir * streak_len

		var alpha := brightness * (0.5 + streak_intensity * 0.5)
		var c := Color(0.7, 0.85, 1.0, clampf(alpha, 0.0, 1.0))

		if streak_len < 3.0:
			canvas.draw_circle(start_pos, sz, c)
		else:
			canvas.draw_line(start_pos, end_pos, c, sz * (0.8 + streak_intensity * 0.5))

static func create() -> HyperspeedTransition:
	var hs := HyperspeedTransition.new()
	return hs
