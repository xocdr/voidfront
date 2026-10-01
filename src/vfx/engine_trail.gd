class_name EngineTrail
extends CPUParticles2D

static func create(color: Color = Color(0.3, 0.7, 1.0, 0.8), trail_scale: float = 1.0) -> EngineTrail:
	var trail := EngineTrail.new()
	trail._configure(color, trail_scale)
	return trail

func _configure(color: Color, trail_scale: float) -> void:
	emitting = true
	amount = 16
	lifetime = 0.35 * trail_scale
	local_coords = false
	direction = Vector2(-1, 0)
	spread = 15.0
	initial_velocity_min = 30.0
	initial_velocity_max = 60.0
	gravity = Vector2.ZERO
	damping_min = 20.0
	damping_max = 50.0
	scale_amount_min = 1.5 * trail_scale
	scale_amount_max = 2.5 * trail_scale

	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r * 0.5, color.g * 0.3, color.b * 0.2, 0.0))
	color_ramp = ramp

	position = Vector2(-12, 0)
