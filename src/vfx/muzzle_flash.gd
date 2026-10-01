class_name MuzzleFlash
extends Node2D

static func spawn(parent: Node, pos: Vector2, dir_angle: float) -> void:
	var flash := MuzzleFlash.new()
	flash.global_position = pos
	flash.rotation = dir_angle
	parent.add_child(flash)
	flash._setup()

func _setup() -> void:
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(-4, -3), Vector2(8, 0), Vector2(-4, 3),
	])
	glow.color = Color(0.9, 1.0, 0.4, 0.9)
	add_child(glow)

	var tween := create_tween()
	tween.tween_property(glow, "color", Color(0.9, 1.0, 0.4, 0.0), 0.06)
	tween.tween_callback(queue_free)
