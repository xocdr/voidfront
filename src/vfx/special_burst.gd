class_name SpecialBurst
extends Node2D

static func spawn(parent: Node, pos: Vector2, radius: float) -> void:
	var effect := SpecialBurst.new()
	effect.global_position = pos
	parent.add_child(effect)
	effect._setup(radius)

func _setup(radius: float) -> void:
	# Expanding ring
	var ring := Line2D.new()
	ring.default_color = Color(0.3, 0.9, 1.0, 0.9)
	ring.width = 4.0
	for j in range(49):
		var angle := j * TAU / 48.0
		ring.add_point(Vector2(cos(angle), sin(angle)) * radius * 0.2)
	add_child(ring)

	# Inner flash
	var flash := CPUParticles2D.new()
	flash.emitting = true
	flash.one_shot = true
	flash.amount = 32
	flash.lifetime = 0.3
	flash.explosiveness = 0.95
	flash.direction = Vector2.ZERO
	flash.spread = 180.0
	flash.initial_velocity_min = 150.0
	flash.initial_velocity_max = 350.0
	flash.gravity = Vector2.ZERO
	flash.damping_min = 200.0
	flash.damping_max = 400.0
	flash.scale_amount_min = 1.5
	flash.scale_amount_max = 3.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.4, 0.95, 1.0, 0.9))
	ramp.set_color(1, Color(0.2, 0.5, 1.0, 0.0))
	flash.color_ramp = ramp
	add_child(flash)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(4.0, 4.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(ring, "default_color", Color(0.3, 0.9, 1.0, 0.0), 0.35)
	tween.tween_property(ring, "width", 1.0, 0.35)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
