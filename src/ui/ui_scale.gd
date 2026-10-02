class_name UiScale
extends RefCounted

# Physical-size-aware scale for UI text and fixed-size widgets. The canvas is a
# 1920x1080 logical viewport, so on a ~6" phone screen a 14 px font is only a
# few points tall. factor() is 1.0 on desktop and ~2.0 on phones/foldables;
# fs() scales a font size and px() scales a pixel dimension. Gameplay is never
# scaled by this — only UI built through these helpers.

const REFERENCE_LOGICAL_PPI: float = 150.0
const MIN_FACTOR: float = 1.0
const MAX_FACTOR: float = 2.0
const BASE_SIZE := Vector2(1920.0, 1080.0)

# Desktop testing: launch with `-- --ui-scale=2` to force a factor.
static func factor() -> float:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ui-scale="):
			return clampf(arg.get_slice("=", 1).to_float(), MIN_FACTOR, MAX_FACTOR)

	var dpi := float(DisplayServer.screen_get_dpi())
	var win := Vector2(DisplayServer.window_get_size())
	if dpi <= 0.0 or win.x <= 0.0 or win.y <= 0.0:
		return 1.0
	# canvas_items + expand: the canvas is scaled by the smaller axis ratio.
	var canvas_scale := minf(win.x / BASE_SIZE.x, win.y / BASE_SIZE.y)
	var logical_ppi := dpi / maxf(canvas_scale, 0.01)
	return clampf(logical_ppi / REFERENCE_LOGICAL_PPI, MIN_FACTOR, MAX_FACTOR)

static func fs(size: int) -> int:
	return roundi(size * factor())

static func px(value: float) -> float:
	return value * factor()

static func vec(v: Vector2) -> Vector2:
	return v * factor()

# Camera zoom for gameplay. The canvas is 1080 logical px tall everywhere, so on
# a phone the ship is only a few millimetres across. Zoom grows at half the rate
# of the UI scale because it also shrinks how much arena the player can see.
static func world_zoom() -> float:
	return 1.0 + (factor() - 1.0) * 0.5
