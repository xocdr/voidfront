# src/ui/crosshair.gd
# Desktop aiming reticle. The ship aims at get_global_mouse_position(), but the
# default OS arrow cursor reads as nearly invisible against the black space
# background, so gameplay hides it and draws this reticle at the cursor's
# screen position instead. Mobile builds aim via auto-aim, not the mouse, so
# this stays inactive there.
class_name Crosshair
extends CanvasLayer

var _mark: Control
var _is_mobile: bool = false
var _active: bool = false

static func create() -> Crosshair:
	return Crosshair.new()

func _ready() -> void:
	layer = 15
	_is_mobile = TouchControls.is_mobile_device()
	if _is_mobile:
		set_process(false)
		return

	_mark = Control.new()
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.size = Vector2(24, 24)
	add_child(_mark)
	_mark.draw.connect(_draw_mark)

	set_active(true)

func _exit_tree() -> void:
	if not _is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func set_active(active: bool) -> void:
	if _is_mobile:
		return
	_active = active
	visible = active
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if active else Input.MOUSE_MODE_VISIBLE

func _process(_delta: float) -> void:
	if not _active:
		return
	_mark.position = get_viewport().get_mouse_position() - _mark.size * 0.5

func _draw_mark() -> void:
	var center := _mark.size * 0.5
	var color := Color(0.5, 0.95, 1.0, 0.85)
	_mark.draw_arc(center, 9.0, 0, TAU, 20, color, 1.5)
	_mark.draw_line(center + Vector2(0, -11), center + Vector2(0, -5), color, 1.5)
	_mark.draw_line(center + Vector2(0, 11), center + Vector2(0, 5), color, 1.5)
	_mark.draw_line(center + Vector2(-11, 0), center + Vector2(-5, 0), color, 1.5)
	_mark.draw_line(center + Vector2(11, 0), center + Vector2(5, 0), color, 1.5)
