# src/ui/hangar_ship_display.gd
class_name HangarShipDisplay
extends Control

var _loadout: ShipLoadoutData
var _equipment: ShipEquipmentState

var _background: Control
var _bg_drift_layers: Array[Node2D] = []
var _ship_root: Node2D
var _shadow: Node2D
var _sprite: ShipSprite
var _engine_glow: PointLight2D
var _particles: GPUParticles2D
var _bob_tween: Tween
var _bg_drift_tweens: Array[Tween] = []

var _previewing_category: String = ""

static func create(loadout: ShipLoadoutData, equipment: ShipEquipmentState) -> HangarShipDisplay:
	var display := HangarShipDisplay.new()
	display.custom_minimum_size = Vector2(480, 480)
	display.call_deferred("_build_ui", loadout, equipment)
	return display

func _build_ui(loadout: ShipLoadoutData, equipment: ShipEquipmentState) -> void:
	_loadout = loadout
	_equipment = equipment

	clip_contents = true

	_build_background()

	var viewport_center := Control.new()
	viewport_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(viewport_center)

	_ship_root = Node2D.new()
	viewport_center.add_child(_ship_root)
	_ship_root.position = size * 0.5

	_build_shadow()
	_build_ship()
	_build_idle_vfx()

	resized.connect(_fit_ship_to_area)
	_fit_ship_to_area()

# The ship scales with the space it is given, so it fills a large panel on a
# tablet without overflowing a short one on a phone.
func _fit_ship_to_area() -> void:
	if _ship_root == null:
		return
	_ship_root.position = size * 0.5
	var fit := clampf(minf(size.x, size.y) / 320.0, 0.5, 2.0)
	_ship_root.scale = Vector2(fit, fit)

func _build_background() -> void:
	_background = Control.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	move_child(_background, 0)

	var far := Node2D.new()
	_background.add_child(far)
	var far_bg := ColorRect.new()
	far_bg.color = Color(0.05, 0.05, 0.1, 1.0)
	far_bg.size = Vector2(1200, 1200)
	far_bg.position = Vector2(-600, -600)
	far.add_child(far_bg)
	_bg_drift_layers.append(far)

	var mid := Node2D.new()
	_background.add_child(mid)
	for i in range(4):
		var pillar := ColorRect.new()
		pillar.color = Color(0.1, 0.12, 0.18, 0.6)
		pillar.size = Vector2(20, 400)
		pillar.position = Vector2(-500 + i * 300, -200)
		mid.add_child(pillar)
	_bg_drift_layers.append(mid)

	for layer in _bg_drift_layers:
		layer.position = size * 0.5

	resized.connect(_reposition_background_layers)
	_start_background_drift()

func _reposition_background_layers() -> void:
	for layer in _bg_drift_layers:
		layer.position = size * 0.5

func _start_background_drift() -> void:
	for tween in _bg_drift_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_bg_drift_tweens.clear()

	# Slow, subtle automatic drift — a few pixels over several seconds, per layer,
	# with distinct offsets/durations so the parallax feels alive without being busy.
	var drift_specs := [Vector2(6.0, 3.0), Vector2(-4.0, 2.0)]
	for i in _bg_drift_layers.size():
		var layer := _bg_drift_layers[i]
		var base_pos: Vector2 = layer.position
		var drift: Vector2 = drift_specs[i % drift_specs.size()]
		var duration := 5.0 + i * 1.5
		var tween := create_tween().set_loops()
		tween.tween_property(layer, "position", base_pos + drift, duration).set_trans(Tween.TRANS_SINE)
		tween.tween_property(layer, "position", base_pos - drift, duration).set_trans(Tween.TRANS_SINE)
		_bg_drift_tweens.append(tween)

const SHIP_ZOOM := 3.8
const SHIP_SKEW_DEG := 8.0

# Flattened, blacked-out copy of the hull parts cast on the hangar deck below
# the ship — same silhouette as the real hull, so it tracks any ship swap.
func _build_shadow() -> void:
	_shadow = Node2D.new()
	_shadow.scale = Vector2(SHIP_ZOOM, SHIP_ZOOM * 0.3)
	_shadow.position = Vector2(0, 70)
	_shadow.modulate = Color(0, 0, 0, 0.35)
	_ship_root.add_child(_shadow)
	_rebuild_shadow()

func _rebuild_shadow() -> void:
	for child in _shadow.get_children():
		_shadow.remove_child(child)
		child.queue_free()
	ShipArt.build_parts(_shadow, ShipArt.get_hull_parts(_loadout.id), Color.BLACK)

func _build_ship() -> void:
	_sprite = ShipSprite.create(_loadout, _equipment, SHIP_ZOOM)
	# Subtle fixed 3/4-perspective tilt via a light shear, not an aggressive distortion.
	_sprite.skew = deg_to_rad(SHIP_SKEW_DEG)
	_ship_root.add_child(_sprite)

func refresh_layer(category: String, upgrade: UpgradeData) -> void:
	if _sprite == null:
		return
	_previewing_category = ""
	_sprite.set_attachment(category, upgrade)

# Unconfirmed previews render in amber rather than the real category tint, so
# a "what would this look like" hover is visually distinct from owned hardware.
const PREVIEW_TINT := Color(1.0, 0.8, 0.25)

func preview_layer(category: String, upgrade: UpgradeData) -> void:
	if _sprite == null:
		return
	_previewing_category = category
	_sprite.set_attachment(category, upgrade, PREVIEW_TINT)

func clear_preview(category: String) -> void:
	if _previewing_category != category:
		return
	_previewing_category = ""
	var upgrade_id: String = _equipment.equipped.get(category, "")
	var upgrade := UpgradeRegistry.get_upgrade(upgrade_id) if not upgrade_id.is_empty() else null
	_sprite.set_attachment(category, upgrade)

func set_ship(loadout: ShipLoadoutData, equipment: ShipEquipmentState) -> void:
	_loadout = loadout
	_equipment = equipment
	_previewing_category = ""
	if _sprite == null:
		# Called before the deferred _build_ui ran; it will pick up the new
		# loadout/equipment when it builds.
		return
	_sprite.set_ship(loadout, equipment)
	_rebuild_shadow()
	if _engine_glow != null:
		_engine_glow.position = (ShipArt.get_attach_offset(loadout.id, "engine") + Vector2(-8, 0)) * SHIP_ZOOM

func _build_idle_vfx() -> void:
	_engine_glow = PointLight2D.new()
	_engine_glow.color = Color(0.3, 0.7, 1.0)
	_engine_glow.energy = 0.6
	_engine_glow.texture = _make_radial_glow_texture()
	_engine_glow.position = (ShipArt.get_attach_offset(_loadout.id, "engine") + Vector2(-8, 0)) * SHIP_ZOOM
	_ship_root.add_child(_engine_glow)

	_particles = GPUParticles2D.new()
	_particles.amount = 12
	_particles.lifetime = 3.0
	_particles.position = Vector2.ZERO
	var mat := ParticleProcessMaterial.new()
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 10.0
	mat.spread = 180.0
	_particles.process_material = mat
	_ship_root.add_child(_particles)

	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(_ship_root, "position:y", _ship_root.position.y - 6.0, 1.6).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(_ship_root, "position:y", _ship_root.position.y + 6.0, 1.6).set_trans(Tween.TRANS_SINE)

	var glow_tween := create_tween().set_loops()
	glow_tween.tween_property(_engine_glow, "energy", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(_engine_glow, "energy", 0.5, 0.8).set_trans(Tween.TRANS_SINE)

func _make_radial_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))

	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex

func play_equip_feedback(category: String) -> void:
	var anchor := ShipArt.get_attach_offset(_loadout.id, category) * SHIP_ZOOM

	var scan := ColorRect.new()
	scan.color = Color(0.6, 0.9, 1.0, 0.5)
	scan.size = Vector2(220, 4)
	scan.position = anchor + Vector2(-110, -120)
	_ship_root.add_child(scan)

	var sweep := create_tween()
	sweep.tween_property(scan, "position:y", anchor.y + 120, 0.4).set_trans(Tween.TRANS_SINE)
	sweep.tween_property(scan, "modulate:a", 0.0, 0.1)
	sweep.tween_callback(scan.queue_free)

	var ring := Polygon2D.new()
	ring.polygon = ShipArt.arc_band(26, 32, 0.0, 359.0, 16)
	ring.color = Color(1, 1, 1, 1)
	ring.modulate.a = 0.0
	ring.position = anchor
	_ship_root.add_child(ring)
	var ring_tween := create_tween()
	ring_tween.tween_property(ring, "modulate:a", 0.8, 0.1)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.4)
	ring_tween.tween_callback(ring.queue_free)
