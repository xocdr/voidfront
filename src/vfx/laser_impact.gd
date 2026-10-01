class_name LaserImpact
extends Node2D

static func spawn(parent: Node, pos: Vector2) -> void:
	var effect := LaserImpact.new()
	effect.global_position = pos
	parent.add_child(effect)
	effect._setup()

func _setup() -> void:
	var sparks := CPUParticles2D.new()
	sparks.emitting = true
	sparks.one_shot = true
	sparks.amount = 8
	sparks.lifetime = 0.2
	sparks.explosiveness = 1.0
	sparks.direction = Vector2.ZERO
	sparks.spread = 180.0
	sparks.initial_velocity_min = 60.0
	sparks.initial_velocity_max = 140.0
	sparks.gravity = Vector2.ZERO
	sparks.damping_min = 200.0
	sparks.damping_max = 400.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.9, 1.0, 0.4, 1.0))
	ramp.set_color(1, Color(0.8, 1.0, 0.2, 0.0))
	sparks.color_ramp = ramp
	add_child(sparks)

	get_tree().create_timer(0.4).timeout.connect(queue_free)
