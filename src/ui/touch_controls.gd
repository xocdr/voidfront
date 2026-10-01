class_name TouchControls
extends CanvasLayer

signal joystick_input(direction: Vector2)
signal fire_pressed
signal fire_released
signal special_pressed

var joystick_base: Control
var joystick_knob: Control
var fire_btn: Control
var special_btn: Control

var joystick_touch_index: int = -1
var fire_touch_index: int = -1
var joystick_center: Vector2
var joystick_direction: Vector2 = Vector2.ZERO
var joystick_radius: float = 80.0
var is_firing: bool = false
var is_mobile: bool = false

func _ready() -> void:
	layer = 80
	is_mobile = _detect_mobile()
	if not is_mobile:
		visible = false
		set_process(false)
		set_process_input(false)
		return
	_build_ui()

func _detect_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()

func _build_ui() -> void:
	var vp_size := get_viewport().get_visible_rect().size

	# Joystick base — bottom-left, circle only
	joystick_base = Control.new()
	joystick_base.position = Vector2(40, vp_size.y - 220)
	joystick_base.size = Vector2(160, 160)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(joystick_base)
	joystick_base.draw.connect(func():
		joystick_base.draw_circle(Vector2(80, 80), 78.0, Color(0.2, 0.5, 0.8, 0.08))
		joystick_base.draw_arc(Vector2(80, 80), 78.0, 0, TAU, 64, Color(0.3, 0.6, 0.9, 0.2), 2.0)
	)
	joystick_base.queue_redraw()

	# Knob — drawn as circle
	joystick_knob = Control.new()
	joystick_knob.position = Vector2(56, 56)
	joystick_knob.size = Vector2(48, 48)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.add_child(joystick_knob)
	joystick_knob.draw.connect(func():
		joystick_knob.draw_circle(Vector2(24, 24), 22.0, Color(0.3, 0.7, 1.0, 0.25))
		joystick_knob.draw_arc(Vector2(24, 24), 22.0, 0, TAU, 48, Color(0.4, 0.8, 1.0, 0.4), 2.0)
	)
	joystick_knob.queue_redraw()

	joystick_center = joystick_base.position + Vector2(80, 80)

	# Fire button — bottom-right
	fire_btn = _make_circle_button("FIRE", Vector2(vp_size.x - 180, vp_size.y - 180), 120, Color(1.0, 0.3, 0.2))
	add_child(fire_btn)

	# Special button — above fire
	special_btn = _make_circle_button("SPEC", Vector2(vp_size.x - 150, vp_size.y - 320), 90, Color(0.3, 0.5, 1.0))
	add_child(special_btn)

func _make_circle_button(text: String, pos: Vector2, btn_size: float, color: Color) -> Control:
	var container := Control.new()
	container.position = pos
	container.size = Vector2(btn_size, btn_size)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var half := btn_size * 0.5
	var fill_color := Color(color.r, color.g, color.b, 0.1)
	var ring_color := Color(color.r, color.g, color.b, 0.25)

	var circle := Control.new()
	circle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(circle)
	circle.draw.connect(func():
		circle.draw_circle(Vector2(half, half), half - 2.0, fill_color)
		circle.draw_arc(Vector2(half, half), half - 2.0, 0, TAU, 64, ring_color, 2.5)
	)
	circle.queue_redraw()

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(color.r, color.g, color.b, 0.5))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(lbl)

	return container

func _input(event: InputEvent) -> void:
	if not is_mobile:
		return

	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _in_joystick_area(event.position):
			joystick_touch_index = event.index
			_update_joystick(event.position)
		elif _in_button_area(event.position, fire_btn):
			fire_touch_index = event.index
			is_firing = true
			fire_pressed.emit()
			Input.action_press("fire")
		elif _in_button_area(event.position, special_btn):
			special_pressed.emit()
			Input.action_press("special")
			get_tree().create_timer(0.1).timeout.connect(func(): Input.action_release("special"))
	else:
		if event.index == joystick_touch_index:
			joystick_touch_index = -1
			joystick_direction = Vector2.ZERO
			joystick_knob.position = Vector2(56, 56)
		if event.index == fire_touch_index:
			fire_touch_index = -1
			is_firing = false
			fire_released.emit()
			Input.action_release("fire")

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == joystick_touch_index:
		_update_joystick(event.position)

func _in_joystick_area(pos: Vector2) -> bool:
	return pos.distance_to(joystick_center) < joystick_radius * 2.5

func _in_button_area(pos: Vector2, btn: Control) -> bool:
	var btn_center := btn.position + btn.size * 0.5
	return pos.distance_to(btn_center) < btn.size.x * 0.75

func _update_joystick(touch_pos: Vector2) -> void:
	var offset := touch_pos - joystick_center
	if offset.length() > joystick_radius:
		offset = offset.normalized() * joystick_radius

	joystick_direction = offset / joystick_radius
	joystick_knob.position = Vector2(56, 56) + offset

	var threshold := 0.2
	if joystick_direction.x < -threshold:
		Input.action_press("move_left", -joystick_direction.x)
		Input.action_release("move_right")
	elif joystick_direction.x > threshold:
		Input.action_press("move_right", joystick_direction.x)
		Input.action_release("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")

	if joystick_direction.y < -threshold:
		Input.action_press("move_up", -joystick_direction.y)
		Input.action_release("move_down")
	elif joystick_direction.y > threshold:
		Input.action_press("move_down", joystick_direction.y)
		Input.action_release("move_up")
	else:
		Input.action_release("move_up")
		Input.action_release("move_down")

func _process(_delta: float) -> void:
	if joystick_touch_index == -1 and is_mobile:
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("move_up")
		Input.action_release("move_down")
