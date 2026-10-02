class_name TouchControls
extends CanvasLayer

# On-screen controls for phones/tablets: a floating joystick (left side), a FIRE
# button and a SPECIAL button (right side). Everything is drawn from one overlay
# Control and laid out from the current viewport size, so it re-fits on rotation
# and on any aspect ratio. Aiming is auto-aim (see player.gd), so there is no
# aim stick.

signal joystick_input(direction: Vector2)
signal fire_pressed
signal fire_released
signal special_pressed

const MOVE_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]
const DEAD_ZONE: float = 0.12
const FIRE_COLOR := Color(1.0, 0.3, 0.2)
const SPECIAL_COLOR := Color(0.3, 0.5, 1.0)
const STICK_COLOR := Color(0.3, 0.7, 1.0)

var overlay: Control

var joystick_touch_index: int = -1
var fire_touch_index: int = -1
var special_touch_index: int = -1
var joystick_direction: Vector2 = Vector2.ZERO
var is_firing: bool = false
var is_mobile: bool = false

# Layout (recomputed in _layout()). All values are in logical viewport pixels.
var _stick_radius: float = 90.0
var _stick_home: Vector2 = Vector2.ZERO      # resting centre of the joystick
var _stick_center: Vector2 = Vector2.ZERO    # centre while a finger is down
var _stick_zone: Rect2 = Rect2()             # where a touch may start the joystick
var _fire_center: Vector2 = Vector2.ZERO
var _fire_radius: float = 90.0
var _special_center: Vector2 = Vector2.ZERO
var _special_radius: float = 64.0

var _player: Node2D = null

# True on phones/tablets. Desktop (including touch-screen laptops, which keep
# mouse aim) stays false. Launch a desktop build with `-- --touch-controls` to
# test the touch layout with the mouse (emulate_touch_from_mouse is on).
static func is_mobile_device() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	return "--touch-controls" in OS.get_cmdline_user_args()

# Notch / rounded-corner / gesture-bar insets as (left, top, right, bottom) in
# logical viewport pixels. Zero on desktop.
static func get_safe_insets(viewport: Viewport) -> Vector4:
	if not is_mobile_device():
		return Vector4.ZERO
	var screen_size := Vector2(DisplayServer.screen_get_size())
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return Vector4.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if safe.size == Vector2.ZERO:
		return Vector4.ZERO
	var vp := viewport.get_visible_rect().size
	var sx := vp.x / screen_size.x
	var sy := vp.y / screen_size.y
	return Vector4(
		maxf(safe.position.x, 0.0) * sx,
		maxf(safe.position.y, 0.0) * sy,
		maxf(screen_size.x - safe.end.x, 0.0) * sx,
		maxf(screen_size.y - safe.end.y, 0.0) * sy)

func _ready() -> void:
	layer = 80
	is_mobile = is_mobile_device()
	if not is_mobile:
		visible = false
		set_process(false)
		set_process_input(false)
		return

	# Touches are also delivered as emulated mouse clicks (needed for menu
	# buttons), and "fire" is bound to the left mouse button — so without this,
	# touching the joystick or anywhere else would also shoot.
	InputMap.action_erase_events("fire")

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)

	get_viewport().size_changed.connect(_layout)
	_layout()

func _exit_tree() -> void:
	if is_mobile:
		_release_all()

func _notification(what: int) -> void:
	# Pausing / hiding stops _input, so a finger lifted meanwhile would leave
	# "fire" or a move action stuck on after resume.
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		if is_mobile:
			_release_all()

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var ins := get_safe_insets(get_viewport())
	var unit := clampf(minf(vp.x, vp.y), 400.0, 1400.0)  # short side drives sizes

	_stick_radius = clampf(unit * 0.13, 70.0, 150.0)
	_fire_radius = clampf(unit * 0.10, 64.0, 130.0)
	_special_radius = _fire_radius * 0.72

	var pad := maxf(unit * 0.05, 28.0)
	var left := ins.x + pad
	var right := vp.x - ins.z - pad
	var bottom := vp.y - ins.w - pad

	_stick_home = Vector2(left + _stick_radius + pad * 0.5, bottom - _stick_radius - pad * 0.5)
	_fire_center = Vector2(right - _fire_radius, bottom - _fire_radius - pad * 0.5)
	_special_center = Vector2(
		_fire_center.x - _fire_radius - _special_radius * 0.55,
		_fire_center.y - _fire_radius - _special_radius * 0.35)
	# keep SPECIAL on screen and clear of FIRE on very narrow viewports
	_special_center.x = maxf(_special_center.x, ins.x + _special_radius)
	_special_center.y = maxf(_special_center.y, ins.y + _special_radius)

	# Left ~45% of the screen below the HUD row starts the (floating) joystick.
	var top := ins.y + vp.y * 0.18
	_stick_zone = Rect2(0.0, top, vp.x * 0.45, vp.y - top)

	if joystick_touch_index == -1:
		_stick_center = _stick_home
	overlay.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Buttons win over the joystick zone so a thumb near FIRE never steers.
		if fire_touch_index == -1 and _in_circle(event.position, _fire_center, _fire_radius * 1.25):
			fire_touch_index = event.index
			is_firing = true
			fire_pressed.emit()
			Input.action_press("fire")
		elif special_touch_index == -1 and _in_circle(event.position, _special_center, _special_radius * 1.3):
			special_touch_index = event.index
			special_pressed.emit()
			Input.action_press("special")
			get_tree().create_timer(0.1, true).timeout.connect(func(): Input.action_release("special"))
		elif joystick_touch_index == -1 and _stick_zone.has_point(event.position):
			joystick_touch_index = event.index
			_stick_center = event.position
			_update_joystick(event.position)
	else:
		if event.index == joystick_touch_index:
			_end_joystick()
		if event.index == fire_touch_index:
			fire_touch_index = -1
			is_firing = false
			fire_released.emit()
			Input.action_release("fire")
		if event.index == special_touch_index:
			special_touch_index = -1
	overlay.queue_redraw()

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == joystick_touch_index:
		_update_joystick(event.position)
		overlay.queue_redraw()

func _in_circle(pos: Vector2, center: Vector2, radius: float) -> bool:
	return pos.distance_to(center) <= radius

func _update_joystick(touch_pos: Vector2) -> void:
	var offset := touch_pos - _stick_center
	# Floating stick: drag the centre along if the thumb goes past the rim, so
	# reversing direction is immediate instead of having to cross the whole stick.
	if offset.length() > _stick_radius:
		_stick_center = touch_pos - offset.normalized() * _stick_radius
		offset = touch_pos - _stick_center

	var raw := offset / _stick_radius
	var mag := raw.length()
	if mag < DEAD_ZONE:
		joystick_direction = Vector2.ZERO
	else:
		# rescale so output ramps from 0 at the dead zone edge to 1 at the rim
		joystick_direction = raw.normalized() * clampf((mag - DEAD_ZONE) / (1.0 - DEAD_ZONE), 0.0, 1.0)
	joystick_input.emit(joystick_direction)
	_apply_move_actions(joystick_direction)

func _apply_move_actions(dir: Vector2) -> void:
	_set_action("move_left", -dir.x)
	_set_action("move_right", dir.x)
	_set_action("move_up", -dir.y)
	_set_action("move_down", dir.y)

func _set_action(action: String, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)

func _end_joystick() -> void:
	joystick_touch_index = -1
	joystick_direction = Vector2.ZERO
	_stick_center = _stick_home
	joystick_input.emit(Vector2.ZERO)
	_apply_move_actions(Vector2.ZERO)

func _release_all() -> void:
	if joystick_touch_index != -1:
		_end_joystick()
	for a in MOVE_ACTIONS:
		Input.action_release(a)
	if is_firing:
		is_firing = false
		fire_released.emit()
	fire_touch_index = -1
	special_touch_index = -1
	joystick_touch_index = -1
	Input.action_release("fire")
	if is_instance_valid(overlay):
		overlay.queue_redraw()

func _process(_delta: float) -> void:
	# Cheap enough to redraw each frame; keeps the SPECIAL cooldown tint live.
	if overlay:
		overlay.queue_redraw()

func _special_ready() -> bool:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return true
	return _player.get("can_special") != false

# --- drawing ---------------------------------------------------------------

func _draw_overlay() -> void:
	var held := joystick_touch_index != -1
	var stick_a := 1.0 if held else 0.55
	var c := _stick_center
	overlay.draw_circle(c, _stick_radius, Color(0.2, 0.5, 0.8, 0.10 * stick_a))
	overlay.draw_arc(c, _stick_radius, 0.0, TAU, 64, Color(0.3, 0.6, 0.9, 0.35 * stick_a), 3.0)
	var knob := c + joystick_direction * _stick_radius
	var knob_r := _stick_radius * 0.42
	overlay.draw_circle(knob, knob_r, Color(STICK_COLOR.r, STICK_COLOR.g, STICK_COLOR.b, 0.30 if held else 0.18))
	overlay.draw_arc(knob, knob_r, 0.0, TAU, 48, Color(0.4, 0.8, 1.0, 0.55 if held else 0.35), 3.0)

	_draw_button(_fire_center, _fire_radius, "FIRE", FIRE_COLOR, fire_touch_index != -1, true)
	var can_burst := _special_ready()
	_draw_button(_special_center, _special_radius, "BURST", SPECIAL_COLOR, special_touch_index != -1, can_burst)

func _draw_button(center: Vector2, radius: float, text: String, color: Color, pressed: bool, enabled: bool) -> void:
	var fill_a := 0.34 if pressed else (0.16 if enabled else 0.05)
	var ring_a := 0.85 if pressed else (0.45 if enabled else 0.18)
	overlay.draw_circle(center, radius - 2.0, Color(color.r, color.g, color.b, fill_a))
	overlay.draw_arc(center, radius - 2.0, 0.0, TAU, 64, Color(color.r, color.g, color.b, ring_a), 3.5)
	var font := ThemeDB.fallback_font
	var fsize := int(radius * 0.28)
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
	overlay.draw_string(font, center + Vector2(-ts.x * 0.5, ts.y * 0.3), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(color.r, color.g, color.b, ring_a + 0.1))
