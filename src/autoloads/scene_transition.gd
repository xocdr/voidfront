extends CanvasLayer

var overlay: ColorRect
var is_transitioning: bool = false

func _ready() -> void:
	layer = 100
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

func change_scene(path: String, duration: float = 0.4) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 1.0, duration)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(path)
	)
	tween.tween_property(overlay, "color:a", 0.0, duration)
	tween.tween_callback(func():
		is_transitioning = false
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)
