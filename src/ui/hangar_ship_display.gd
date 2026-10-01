# src/ui/hangar_ship_display.gd
class_name HangarShipDisplay
extends Control

const CATEGORY_ATTACH_OFFSETS := {
	"weapons": Vector2(18, -4),
	"engine": Vector2(-18, 0),
	"shield": Vector2(0, 0),
	"armor": Vector2(0, 8),
}

var _loadout: ShipLoadoutData
var _equipment: ShipEquipmentState

var _background: ParallaxBackground
var _ship_root: Node2D
var _shadow_shape: Polygon2D
var _base_shape: Polygon2D
var _category_layers: Dictionary = {}
var _engine_glow: Light2D
var _particles: GPUParticles2D
var _bob_tween: Tween

static func create(loadout: ShipLoadoutData, equipment: ShipEquipmentState) -> HangarShipDisplay:
	var display := HangarShipDisplay.new()
	display.custom_minimum_size = Vector2(480, 480)
	display.call_deferred("_build_ui", loadout, equipment)
	return display

func _build_ui(loadout: ShipLoadoutData, equipment: ShipEquipmentState) -> void:
	_loadout = loadout
	_equipment = equipment

	_build_background()

	var viewport_center := Control.new()
	viewport_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(viewport_center)

	_ship_root = Node2D.new()
	viewport_center.add_child(_ship_root)
	_ship_root.position = size * 0.5

	_build_shadow()
	_build_base_ship()
	_build_category_layers()
	_build_idle_vfx()

	resized.connect(func(): _ship_root.position = size * 0.5)

func _build_background() -> void:
	_background = ParallaxBackground.new()
	add_child(_background)
	move_child(_background, 0)

	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.1, 0.1)
	_background.add_child(far)
	var far_bg := ColorRect.new()
	far_bg.color = Color(0.05, 0.05, 0.1, 1.0)
	far_bg.size = Vector2(1200, 1200)
	far_bg.position = Vector2(-600, -600)
	far.add_child(far_bg)

	var mid := ParallaxLayer.new()
	mid.motion_scale = Vector2(0.3, 0.3)
	_background.add_child(mid)
	for i in range(4):
		var pillar := ColorRect.new()
		pillar.color = Color(0.1, 0.12, 0.18, 0.6)
		pillar.size = Vector2(20, 400)
		pillar.position = Vector2(-500 + i * 300, -200)
		mid.add_child(pillar)

func _build_shadow() -> void:
	_shadow_shape = Polygon2D.new()
	_shadow_shape.polygon = _loadout.polygon_points
	_shadow_shape.color = Color(0, 0, 0, 0.35)
	_shadow_shape.scale = Vector2(4.2, 1.2)
	_shadow_shape.position = Vector2(0, 60)
	_ship_root.add_child(_shadow_shape)

func _build_base_ship() -> void:
	_base_shape = Polygon2D.new()
	_base_shape.polygon = _loadout.polygon_points
	_base_shape.color = _loadout.color
	_base_shape.scale = Vector2(4.0, 4.0)
	# Subtle fixed 3/4-perspective tilt via a light shear, not an aggressive distortion.
	_base_shape.skew = deg_to_rad(8.0)
	_ship_root.add_child(_base_shape)

func _build_category_layers() -> void:
	for category in UpgradeRegistry.get_categories():
		var layer := Polygon2D.new()
		layer.polygon = PackedVector2Array([Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)])
		layer.color = Color(1, 1, 1, 0.0)
		layer.position = CATEGORY_ATTACH_OFFSETS.get(category, Vector2.ZERO) * 4.0
		_ship_root.add_child(layer)
		_category_layers[category] = layer

		var upgrade_id: String = _equipment.equipped.get(category, "")
		var upgrade := UpgradeRegistry.get_upgrade(upgrade_id) if not upgrade_id.is_empty() else null
		if upgrade != null:
			_apply_layer_visual(category, upgrade)

func refresh_layer(category: String, upgrade: UpgradeData) -> void:
	if not _category_layers.has(category):
		return
	_apply_layer_visual(category, upgrade)

func _apply_layer_visual(category: String, upgrade: UpgradeData) -> void:
	var layer: Polygon2D = _category_layers[category]
	# Placeholder visual: tier-0 items are invisible (no accent), higher tiers get a category-tinted accent.
	# This is the seam where real per-upgrade art replaces the tint later without touching any other layer.
	if upgrade.tier <= 0:
		layer.color = Color(1, 1, 1, 0.0)
		return
	match category:
		"weapons":
			layer.color = Color(1.0, 0.3, 0.2, 0.9)
		"engine":
			layer.color = Color(0.3, 0.7, 1.0, 0.9)
		"shield":
			layer.color = Color(0.3, 1.0, 0.8, 0.9)
		"armor":
			layer.color = Color(0.8, 0.8, 0.3, 0.9)
		_:
			layer.color = Color(1, 1, 1, 0.9)

func set_ship(loadout: ShipLoadoutData, equipment: ShipEquipmentState) -> void:
	_loadout = loadout
	_equipment = equipment
	_base_shape.polygon = loadout.polygon_points
	_base_shape.color = loadout.color
	_shadow_shape.polygon = loadout.polygon_points
	for category in UpgradeRegistry.get_categories():
		var upgrade_id: String = equipment.equipped.get(category, "")
		var upgrade := UpgradeRegistry.get_upgrade(upgrade_id) if not upgrade_id.is_empty() else null
		if upgrade != null:
			_apply_layer_visual(category, upgrade)

func _build_idle_vfx() -> void:
	_engine_glow = PointLight2D.new()
	_engine_glow.color = Color(0.3, 0.7, 1.0)
	_engine_glow.energy = 0.6
	_engine_glow.position = CATEGORY_ATTACH_OFFSETS["engine"] * 4.0
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

func play_equip_feedback(category: String) -> void:
	if not _category_layers.has(category):
		return
	var layer: Polygon2D = _category_layers[category]

	var scan := ColorRect.new()
	scan.color = Color(0.6, 0.9, 1.0, 0.5)
	scan.size = Vector2(160, 4)
	scan.position = layer.position + Vector2(-80, -100)
	_ship_root.add_child(scan)

	var sweep := create_tween()
	sweep.tween_property(scan, "position:y", layer.position.y + 100, 0.4).set_trans(Tween.TRANS_SINE)
	sweep.tween_property(scan, "modulate:a", 0.0, 0.1)
	sweep.tween_callback(scan.queue_free)

	var ring := Polygon2D.new()
	ring.polygon = PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)])
	ring.color = Color(1, 1, 1, 0.0)
	ring.position = layer.position
	_ship_root.add_child(ring)
	var ring_tween := create_tween()
	ring_tween.tween_property(ring, "modulate:a", 0.8, 0.1)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.4)
	ring_tween.tween_callback(ring.queue_free)
