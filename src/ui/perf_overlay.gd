class_name PerfOverlay
extends CanvasLayer

# Debug-only frame-time readout with A/B toggles. Shown in debug builds (the
# test APKs) so slow spots can be reported with numbers; release exports never
# create it. Tap a toggle and watch FPS / frame time to see what it costs.

var label: Label
var buttons: HBoxContainer
var _accum: float = 0.0

var _bg_on := true
var _traffic_on := true
var _fx_on := true
var _lowres_on := false

static func create() -> PerfOverlay:
	return PerfOverlay.new()

func _ready() -> void:
	layer = 100
	var box := VBoxContainer.new()
	box.position = Vector2(UiScale.px(16.0), UiScale.px(88.0))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	label = Label.new()
	label.add_theme_font_size_override("font_size", UiScale.fs(11))
	label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", roundi(UiScale.px(6.0)))
	box.add_child(buttons)
	_add_toggle("BG", _toggle_bg)
	_add_toggle("TRAFFIC", _toggle_traffic)
	_add_toggle("FX", _toggle_fx)
	_add_toggle("LOWRES", _toggle_lowres)

func _add_toggle(text: String, handler: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = UiScale.vec(Vector2(64, 36))
	b.add_theme_font_size_override("font_size", UiScale.fs(11))
	b.toggled.connect(handler)
	buttons.add_child(b)

func _toggle_bg(on: bool) -> void:
	_bg_on = on
	var bg := get_parent().get_node_or_null("Background")
	if bg:
		bg.visible = on

func _toggle_traffic(on: bool) -> void:
	_traffic_on = on
	var node: Node = get_parent().get("midground_traffic")
	if node:
		node.visible = on
		node.set_process(on)
		node.set_physics_process(on)

func _toggle_fx(on: bool) -> void:
	_fx_on = on
	_apply_fx()

func _toggle_lowres(on: bool) -> void:
	# The toggle is "full quality" when pressed; off renders the 1920x1080 base
	# canvas and upscales it, which is far cheaper on a big, dense screen.
	_lowres_on = not on
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT if _lowres_on else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

func _apply_fx() -> void:
	for p in get_parent().find_children("*", "CPUParticles2D", true, false):
		if _fx_on:
			p.visible = true
		else:
			p.visible = false
			p.emitting = false

func _process(delta: float) -> void:
	_accum += delta
	if _accum < 0.5:
		return
	_accum = 0.0
	if not _fx_on:
		_apply_fx()
	label.text = "FPS %d  frame %.1f ms\nproc %.1f ms  phys %.1f ms\ndraws %d  objs %d\nnodes %d  enemies %d\nres %dx%d" % [
		Performance.get_monitor(Performance.TIME_FPS),
		1000.0 / maxf(Performance.get_monitor(Performance.TIME_FPS), 1.0),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		get_tree().get_nodes_in_group("enemies").size(),
		DisplayServer.window_get_size().x, DisplayServer.window_get_size().y,
	]
