class_name ExplosionEffect
extends Node2D

static func spawn(parent: Node, pos: Vector2, scale_mult: float = 1.0, color: Color = Color(1.0, 0.6, 0.2)) -> void:
	var effect := ExplosionEffect.new()
	effect.global_position = pos
	parent.add_child(effect)
	effect._setup(scale_mult, color)

func _setup(scale_mult: float, color: Color) -> void:
	# Core burst
	var burst := CPUParticles2D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.amount = int(16 * scale_mult)
	burst.lifetime = 0.4
	burst.explosiveness = 0.95
	burst.direction = Vector2.ZERO
	burst.spread = 180.0
	burst.initial_velocity_min = 80.0 * scale_mult
	burst.initial_velocity_max = 200.0 * scale_mult
	burst.gravity = Vector2.ZERO
	burst.damping_min = 100.0
	burst.damping_max = 200.0
	burst.scale_amount_min = 2.0 * scale_mult
	burst.scale_amount_max = 4.5 * scale_mult
	burst.scale_amount_curve = _get_fade_curve()
	burst.color = color
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, color)
	color_ramp.set_color(1, Color(color.r, color.g * 0.3, 0.0, 0.0))
	burst.color_ramp = color_ramp
	add_child(burst)

	# Bright flash
	var flash := CPUParticles2D.new()
	flash.emitting = true
	flash.one_shot = true
	flash.amount = 4
	flash.lifetime = 0.15
	flash.explosiveness = 1.0
	flash.direction = Vector2.ZERO
	flash.spread = 180.0
	flash.initial_velocity_min = 0.0
	flash.initial_velocity_max = 20.0
	flash.gravity = Vector2.ZERO
	flash.scale_amount_min = 6.0 * scale_mult
	flash.scale_amount_max = 10.0 * scale_mult
	var flash_ramp := Gradient.new()
	flash_ramp.set_color(0, Color(1.0, 1.0, 0.9, 0.9))
	flash_ramp.set_color(1, Color(1.0, 0.8, 0.4, 0.0))
	flash.color_ramp = flash_ramp
	add_child(flash)

	# Debris sparks
	var sparks := CPUParticles2D.new()
	sparks.emitting = true
	sparks.one_shot = true
	sparks.amount = int(8 * scale_mult)
	sparks.lifetime = 0.6
	sparks.explosiveness = 0.9
	sparks.direction = Vector2.ZERO
	sparks.spread = 180.0
	sparks.initial_velocity_min = 120.0 * scale_mult
	sparks.initial_velocity_max = 300.0 * scale_mult
	sparks.gravity = Vector2.ZERO
	sparks.damping_min = 50.0
	sparks.damping_max = 150.0
	sparks.scale_amount_min = 0.8
	sparks.scale_amount_max = 1.5
	var spark_ramp := Gradient.new()
	spark_ramp.set_color(0, Color(1.0, 0.9, 0.5))
	spark_ramp.set_color(1, Color(1.0, 0.3, 0.0, 0.0))
	sparks.color_ramp = spark_ramp
	add_child(sparks)

	get_tree().create_timer(1.0).timeout.connect(queue_free)

# One shared curve for every explosion instead of building a new one per spawn.
static var _fade_curve: Curve

func _get_fade_curve() -> Curve:
	if _fade_curve == null:
		_fade_curve = Curve.new()
		_fade_curve.add_point(Vector2(0.0, 1.0))
		_fade_curve.add_point(Vector2(0.3, 0.8))
		_fade_curve.add_point(Vector2(1.0, 0.0))
	return _fade_curve
